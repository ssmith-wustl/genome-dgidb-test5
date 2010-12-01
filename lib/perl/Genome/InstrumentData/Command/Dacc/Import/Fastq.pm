package Genome::InstrumentData::Command::Dacc::Import::Fastq;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;
require File::Copy;
require File::Path;

class Genome::InstrumentData::Command::Dacc::Import::Fastq {
    is  => 'Genome::InstrumentData::Command::Dacc::Import',
    has => [
        format => {
            is => 'Text',
            is_constant => 1,
            value => 'sanger fastq',
        },
        _paired_read_count => { is => 'Integer', is_optional => 1},
        _fwd_fastq => { 
            calculate_from => '_absolute_path',
            calculate => q| return $_absolute_path.'/s_1_1_sequence.txt'; |, 
        },
        _rev_fastq => { calculate_from => '_absolute_path',
            calculate => q| return $_absolute_path.'/s_1_2_sequence.txt'; |,
        },
        _singleton_instrument_data => { is_optional => 1},
        _singleton_read_count => { is => 'Integer', is_optional => 1},
        _singleton_fastq => { calculate_from => '_absolute_path',
            calculate => q| return $_absolute_path.'/s_2_sequence.txt'; |,
        },
    ],
};

sub help_brief {
    return 'Import the downloaded fastqs from the DACC';
}

sub help_detail {
    return help_brief();
}

sub _execute {
    my $self = shift;

    my $unzip = $self->_unzip_fastqs;
    return if not $unzip;

    my $rename = $self->_rename_fastqs;
    return if not $rename;

    my $read_cnts = $self->_validate_fastq_read_counts;
    return if not $read_cnts;

    my $singleton = $self->_get_or_create_singleton_instrument_data;
    return if not $singleton;

    my $import = $self->_archive_and_update;
    return if not $import;

    return 1;
}

sub _unzip_fastqs {
    my $self = shift;

    my $dl_directory = $self->_dl_directory;
    my @zipped_fastqs = glob($dl_directory.'/*.fastq.bz2');

    return 1 if not @zipped_fastqs; # ok

    $self->status_message('Unzip fastqs...');

    for my $zipped_fastq ( @zipped_fastqs ) {
        my $cmd = "bunzip2 -f $zipped_fastq";
        $self->status_message($cmd);
        my $rv = eval{ Genome::Utility::FileSystem->shellcmd(cmd => $cmd); };
        if ( not $rv ) {
            $self->error_message("Cannot unzip fastq: $zipped_fastq");
            return;
        }
    }
    $self->status_message('Unzip fastqs...OK');

    return 1;
}

sub _rename_fastqs {
    my $self = shift;

    $self->status_message('Rename fastqs...');

    my $dl_directory = $self->_dl_directory;

    # fwd
    my $fwd_fastq = $self->_fwd_fastq;
    if ( my ($dl_fwd_fastq) = glob($dl_directory.'/*.1.fastq') ) { # dl = orignal download file name
        rename $dl_fwd_fastq, $fwd_fastq;
    }
    if ( not -e $fwd_fastq ) {
        $self->error_message('Forward fastq not found in download directory: '.$dl_directory);
        return;
    }

    #rev
    my $rev_fastq = $self->_rev_fastq;
    if ( my ($dl_rev_fastq) = glob($dl_directory.'/*.2.fastq') ) { # dl = orignal download file name
        rename $dl_rev_fastq, $rev_fastq;
    }
    if ( not -e $rev_fastq ) {
        $self->error_message('Reverse fastq not found in download directory: '.$dl_directory);
        return;
    }

    # singleton
    my $singleton_fastq = $self->_singleton_fastq;
    if ( my ($dl_singleton_fastq) = glob($dl_directory.'/*.singleton.fastq') ) { # dl = orignal download file name
        rename $dl_singleton_fastq, $singleton_fastq;
    }
    if ( not -e $singleton_fastq ) {
        $self->error_message('Singleton fastq not found in download directory: '.$dl_directory);
        return;
    }
    $self->status_message('Rename fastqs...OK');

    return 1;
}

sub _validate_fastq_read_counts {
    my $self = shift;

    $self->status_message('Validate fastq read counts...');

    my $fwd_read_count = $self->_read_count_for_fastq( $self->_fwd_fastq );
    return if not defined $fwd_read_count;
    my $rev_read_count = $self->_read_count_for_fastq( $self->_rev_fastq );
    return if not defined $rev_read_count;
    if ( $fwd_read_count != $rev_read_count ) {
        $self->error_message("Read counts for foward/reverse fastqs does not match: $fwd_read_count <=> $rev_read_count");
        return;
    }
    $self->_paired_read_count( $fwd_read_count + $rev_read_count );
    $self->status_message('Paired read count: '.$self->_paired_read_count);

    my $singleton_read_count = $self->_read_count_for_fastq( $self->_singleton_fastq );
    return if not defined $singleton_read_count;
    $self->_singleton_read_count($singleton_read_count);
    $self->status_message('Singleton read count: '.$self->_singleton_read_count);

    $self->status_message('Validate fastq read counts...OK');

    return 1;
}

sub _read_count_for_fastq {
    my ($self, $fastq) = @_;

    my $line_count = `wc -l < $fastq`;
    if ( $? or not $line_count ) {
        $self->error_message("Line count on fastq ($fastq) failed.");
        return;
    }

    chomp $line_count;
    if ( ($line_count % 4) != 0 ) {
        $self->error_message("Line count ($line_count) on fastq ($fastq) not divisble by 4.");
        return;
    }

    return $line_count / 4;
}

sub _get_or_create_singleton_instrument_data {
    my $self = shift;

    my @instrument_data = $self->_get_instrument_data;
    if ( @instrument_data == 2 ) {
        $self->status_message('Got singelton instrument data: '.$instrument_data[1]->id);
        $self->_singleton_instrument_data($instrument_data[1]);
        return 1;
    }
    elsif ( @instrument_data > 2 ) {
        $self->error_message('Somehow there are more than two instrument data to import fastqs. Please fix.');
        return;
    }

    $self->status_message('Create singelton instrument data');

    my $singleton_fastq = $self->_singleton_fastq;
    my $size = -s $singleton_fastq;
    my $kilobytes_requested = int($size / 950); # 5% xtra space
    my $singleton_instrument_data = $self->_create_instrument_data(
        kilobytes_requested => $kilobytes_requested,
    );
    if ( not $singleton_instrument_data ) {
        $self->error_message('Failed to create singelton instrument data. See above errors.');
        return;
    }
    $self->_singleton_instrument_data($singleton_instrument_data);

    $self->status_message('Create singelton instrument data: '.$self->_singleton_instrument_data->id);

    return $singleton_instrument_data;
}

sub _archive_and_update {
    my $self = shift;

    $self->status_message('Create archives...');

    my $paired_instrument_data = $self->_main_instrument_data;
    my $singleton_instrument_data = $self->_singleton_instrument_data;
    my $dl_directory = $self->_dl_directory;

    #<PAIRED>#
    my $archive = $self->_create_archive($paired_instrument_data, $self->_fwd_fastq_base_name, $self->_rev_fastq_base_name);
    return if not $archive;

    #<SINGLETON>#
    $archive = $self->_create_archive($singleton_instrument_data, $self->_singleton_fastq);
    return if not $archive;

    $self->status_message('Removing original fastqs...');
    unlink $self->_fwd_fastq;
    unlink $self->_rev_fastq;
    unlink $self->_singleton_fastq;
    $self->status_message('Removing original fastqs...OK');

    $self->status_message('Update instrument data...');
    $paired_instrument_data->description($self->sra_sample_id.' Pairs that have been human screened, Q2 trimmed and deduped from the DACC');
    $paired_instrument_data->original_data_path(join(',', $self->_fwd_fastq, $self->_rev_fastq));
    $paired_instrument_data->read_count( $self->_paired_read_count );
    $paired_instrument_data->is_paired_end(1);

    $singleton_instrument_data->description($self->sra_sample_id.' Singletons that have been human screened, Q2 trimmed and deduped from the DACC');
    $singleton_instrument_data->original_data_path($self->_singleton_fastq);
    $singleton_instrument_data->read_count( $self->_singleton_read_count );
    $self->status_message('Update instrument data...OK');

    $self->status_message('Update instrument data...OK');
    
    return 1;
}

sub _create_archive {
    my ($self, $instrument_data, @fastqs) = @_;

    $self->status_message('Archive fastqs: '. $instrument_data->id);

    # Tar to temp file in alloc dir
    my $dl_directory = $self->_dl_directory;

    my $temp_tar_file = $dl_directory.'/temp.tgz';
    unlink $temp_tar_file if -e $temp_tar_file;
    $self->status_message("Tar-ing fastqs to $temp_tar_file");
    my $tar_cmd = "tar cvzf $temp_tar_file -C $dl_directory ".join(' ', @fastqs);
    $self->status_message($tar_cmd);
    my $rv = eval { Genome::Utility::FileSystem->shellcmd(cmd => $tar_cmd); };
    if ( not $rv ) {
        $self->error_message("Tar command failed: $tar_cmd");
        return;
    }
    $self->status_message("Tar-ing OK");

    # Rename temp tar file to 'archive.tgz'
    my $archive_path = $instrument_data->archive_path;
    $self->status_message("Rename $temp_tar_file to $archive_path");
    unlink $archive_path if -e $archive_path;
    rename $temp_tar_file, $archive_path;
    if ( not -s $archive_path ) {
        $self->error_message("Failed to rename $temp_tar_file to $archive_path");
        return;
    }
    $self->status_message('Rename archive...OK');

    $self->status_message('Archive fastqs...OK');

    return 1;
}

1;

