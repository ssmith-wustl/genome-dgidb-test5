package Genome::InstrumentData::Command::Dacc::Import::Fastq;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;
require File::Path;

class Genome::InstrumentData::Command::Dacc::Import::Fastq {
    is  => 'Genome::InstrumentData::Command::Dacc::Import',
    has => [
        format => {
            is => 'Text',
            is_constant => 1,
            value => 'sanger fastq',
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

    my $singleton = $self->_get_or_create_singleton_instrument_data(create_allocation => 1);
    return if not $singleton;

    my $read_cnts = $self->_validate_fastq_read_counts;
    return if not $read_cnts;

    my $import = $self->_import_fastqs;
    return if not $import;

    $self->status_message('Import...OK');

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

sub _get_singleton_instrument_data {
    my ($self, %params) = @_;

    $self->status_message('Get singleton instrument data...');

    my @instrument_data = $self->_get_instrument_data_for_sra_sample_id;
    return if not @instrument_data;

    my ($singleton_inst_data) = grep { not $_->is_paired_end } @instrument_data;
    if ( not $singleton_inst_data ) {
        $self->status_message('No singleton instrument data');
        return;
    }

    $self->_singleton_inst_data( $singleton_inst_data );

    if ( not $self->_singleton_allocation ) {
        if ( $params{create_allocation} ) {
            my $allocation = $self->_create_singleton_instrument_data_allocation;
            return if not $allocation;
        }
        else {
            $self->error_message('No allocation for singleton instrument data, and did not request to create one');
            return;
        }
    }

    $self->status_message('Singleton instrument data: '.$singleton_inst_data->id);

    return $self->_singleton_inst_data;
}
sub _create_singleton_instrument_data {
    my $self =  shift;

    $self->status_message('Create singleton instrument data...');

    if ( $self->_get_singleton_instrument_data(create_allocation => 1) ) {
        $self->status_message('Singleton instrument data already exists.');
        return $self->_singleton_inst_data;
    }

    my $singleton_inst_data = Genome::InstrumentData::Imported->create(
        sample_id => $self->_sample->id,
        sample_name => $self->sra_sample_id,
        library_id => $self->_library->id,
        sra_sample_id => $self->sra_sample_id, 
        sequencing_platform => 'solexa',
        import_format => $self->format,
        import_source_name => 'DACC',
        original_data_path => 0, 
        subset_name => '2-DACC',
        description => $self->sra_sample_id.' Singletons that have been human screened, Q2 trimmed and deduped from the DACC',
    );

    if ( not defined $singleton_inst_data) {
        $self->error_message('Cannot create singleton instrument data for sra sample id: '.$self->sra_sample_id);
        return;
    }

    if ( not UR::Context->commit ) {
        $self->error_message('Cannot commit singleton instrument data.');
        return;
    }

    $self->_singleton_inst_data($singleton_inst_data);

    my $allocation = $self->_create_singleton_instrument_data_allocation;
    return if not $allocation;

    $self->status_message('Create singleton instrument data...');

    return $self->_singleton_inst_data;
}

sub _create_singleton_instrument_data_allocation {
    my $self =  shift;

    $self->status_message('Create singleton instrument data allocation...');

    if ( defined $self->_singleton_allocation ) {
        $self->status_message('Allocation for singleton instrument already exists');
        return;
    }

    my $singleton_inst_data = $self->_singleton_inst_data;
    my $singleton_allocation = Genome::Disk::Allocation->allocate(
        owner_id => $singleton_inst_data->id,
        owner_class_name => $singleton_inst_data->class,
        disk_group_name => 'info_alignments',
        allocation_path => 'instrument_data/imported/'.$singleton_inst_data->id,
        kilobytes_requested => 40_000_000, # 50 Gb, will go down
    );

    if ( not defined $singleton_allocation ) {
        $self->error_message('Could not create disk allocation for singleton instrument data: '.$singleton_inst_data->id);
        return;
    }

    $self->status_message('Create singleton instrument data allocation...OK');

    return $self->_singleton_allocation;
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
    $self->_paired_inst_data->read_count( $fwd_read_count + $rev_read_count );

    my $singleton_read_count = $self->_read_count_for_fastq( $self->_singleton_fastq );
    return if not defined $singleton_read_count;
    $self->_singleton_inst_data->read_count($singleton_read_count);

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

sub _import_fastqs {
    my $self = shift;

    $self->status_message('Import fastqs...');

    my $dl_directory = $self->_dl_directory;

    #<PAIRED>#
    $self->status_message('Import paired fastqs...');

    # Tar to temp file in alloc dir
    my $paired_absolute_path = $self->_paired_absolute_path;
    my $paired_temp_tar_file = $paired_absolute_path.'/paired.temp.tgz';
    unlink $paired_temp_tar_file if -e $paired_temp_tar_file;
    $self->status_message("Tar-ing paired fastqs to $paired_temp_tar_file");
    my $tar_cmd = "tar cvzf $paired_temp_tar_file -C $dl_directory ".$self->_fwd_fastq_base_name.' '.$self->_rev_fastq_base_name;
    $self->status_message($tar_cmd);
    my $rv = eval { Genome::Utility::FileSystem->shellcmd(cmd => $tar_cmd); };
    if ( not $rv ) {
        $self->error_message("Tar command failed: $tar_cmd");
        return;
    }
    $self->status_message("Tar-ing OK");

    # Rename temp tar file to 'archive.tgz'
    my $paired_tar_file = $self->_paired_absolute_path.'/archive.tgz';
    $self->status_message("Rename $paired_temp_tar_file to $paired_tar_file");
    unlink $paired_tar_file if -e $paired_tar_file;
    rename $paired_temp_tar_file, $paired_tar_file;
    if ( not -s $paired_tar_file ) {
        $self->error_message("Failed to rename $paired_temp_tar_file to $paired_tar_file");
        return;
    }
    $self->status_message("Rename paired tar file OK");
    $self->status_message('Import paired fastqs...OK');

    #<SINGLETON>#
    $self->status_message('Import singleton fastq...');

    # Tar to temp file in alloc dir
    my $singleton_absolute_path = $self->_singleton_absolute_path;
    my $singleton_temp_tar_file = $singleton_absolute_path.'/singleton.temp.tgz';
    unlink $singleton_temp_tar_file if -e $singleton_temp_tar_file;
    $self->status_message("Tar-ing singleton fastqs to $singleton_temp_tar_file");
    $tar_cmd = "tar cvzf $singleton_temp_tar_file -C $dl_directory ".$self->_singleton_fastq_base_name;
    $self->status_message($tar_cmd);
    $rv = eval { Genome::Utility::FileSystem->shellcmd(cmd => $tar_cmd); };
    if ( not $rv ) {
        $self->error_message("Tar command failed: $tar_cmd");
        return;
    }
    $self->status_message("Tar-ing OK");

    # Rename temp tar file to 'archive.tgz'
    my $singleton_tar_file = $singleton_absolute_path.'/archive.tgz';
    $self->status_message("Rename $singleton_temp_tar_file to $singleton_tar_file");
    unlink $singleton_tar_file if -e $singleton_tar_file;
    rename $singleton_temp_tar_file, $singleton_tar_file;
    if ( not -s $singleton_tar_file ) {
        $self->error_message("Failed to rename $singleton_temp_tar_file to $singleton_tar_file");
        return;
    }
    $self->status_message("Rename singleton tar file OK");
    $self->status_message('Import paired fastqs...OK');

    $self->status_message('Import singleton fastq...OK');

    #<ORIGINAL PATH>#
    $self->_paired_inst_data->original_data_path(join(',', $self->_fwd_fastq, $self->_rev_fastq));
    $self->_singleton_inst_data->original_data_path($self->_singleton_fastq);

    #<CLEANUP & REALLOCATE>#
    # Rm original fastqs
    $self->status_message('Removing original fastqs...');
    unlink $self->_fwd_fastq;
    unlink $self->_rev_fastq;
    unlink $self->_singleton_fastq;
    $self->status_message('Removing original fastqs...OK');
    
    # Reallocate
    $self->status_message('Reallocate...');
    my $paired_allocation = $self->_paired_allocation;
    if ( not $paired_allocation->reallocate ) {
        $self->error_message(
            'Failed to reallocate paired instrument data allocation: '.$self->_paired_inst_data->id
        );
    }
    my $singleton_allocation = $self->_singleton_allocation;
    if ( not $singleton_allocation->reallocate ) {
        $self->error_message(
            'Failed to reallocate singleton instrument data allocation: '.$self->_singleton_inst_data->id
        );
    }
    $self->status_message('Reallocate...OK');

    return 1;
}

sub _update_instrument_data {
    my $self = shift;

    $self->status_message('Update instrument data...');

    # Inst data attrs
    my $instrument_data = $self->_inst_data;
    $instrument_data->description($self->sra_sample_id.' SFF from the DACC');
    # FIXME can we do more?
    #

        #subset_name => '1-DACC',
        #is_paired_end => 1,
        #description => $self->sra_sample_id.' Pairs that have been human screened, Q2 trimmed and deduped from the DACC',

    # Realloc
    my ($allocation) = $instrument_data->disk_allocations;
    Carp::confess('No disk allocation for instrument data: '.$instrument_data->id) if not $allocation;
    if ( not $allocation->reallocate ) { # disregard error
        $self->error_message('Failed to reallocate instrument data allocation: '.$instrument_data->id);
    }

    $self->status_message('Update instrument data...OK');

    return 1;
}

1;

