package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Temp;
require IPC::Run;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
    has => [
        _metrics => {
            is => 'Hash',
            is_optional => 1,
            default_value => { bases => 0, count => 0 },
        },
        _base_limit => {
            is => 'Integer',
            is_optional => 1,
        },
    ],
};

sub bsub_rusage {
    return "-R 'select[type==LINUX64 && tmp>20000] rusage[tmp=20000] span[hosts=1]'"
}

sub _tempdir {
    my $self = shift;

    unless ( $self->{_tempdir} ) {
        $self->{_tempdir} = File::Temp::tempdir(CLEANUP => 1 );
        Genome::Sys->validate_existing_directory( $self->{_tempdir} )
            or die;
    }
    
    return $self->{_tempdir};
}

sub _metrics_file { 
    return $_[0]->_tempdir.'/metrics.txt';
}

#< Execute >#
sub execute {
    my $self = shift;

    my $processing_profile = $self->processing_profile;
    $self->status_message('Preparing instrument data for '.$processing_profile->assembler_base_name.' '.$processing_profile->sequencing_platform);

    $self->status_message('Verifying instrument data...');

    my @instrument_data = $self->build->instrument_data;

    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }
    $self->status_message('OK...instrument data');

    $self->status_message('Setup base limit');
    $self->_setup_base_limit;
    $self->status_message('OK...setup base limit');

    my @existing_assembler_input_files = $self->build->existing_assembler_input_files;
    if ( @existing_assembler_input_files ) { 
        $self->status_message('Removing existing assembler input files');
        for my $file ( @existing_assembler_input_files ) {
            unlink $file;
            if ( -e $file ) {
                $self->error_message("Cannot remove existing assembler input file $file");
                return;
            }
        }
    }

    $self->status_message('Processing instrument data');
    my $sequencing_platform = $processing_profile->sequencing_platform;
    my $file_method = '_fastq_files_from_'.$sequencing_platform;
    INST_DATA: for my $instrument_data ( @instrument_data ) {
        $self->_process_instrument_data($instrument_data)
            or return;
        if ( $self->_is_there_a_base_limit_and_has_it_been_exceeded ) {
            $self->status_message('Reached base limit: '.$self->_base_limit);
            last INST_DATA;
        }
    }
    $self->status_message('OK...processing instrument data');

    $self->status_message('Verifying assembler input files');
    @existing_assembler_input_files = $self->build->existing_assembler_input_files;
    if ( not @existing_assembler_input_files ) {
        $self->error_message('No assembler input files were created!');
        return;
    }
    $self->status_message('OK...assembler input files');

    $self->status_message('OK...prepare instrument data');

    return 1;
}
#<>#

#< Base Limit >#
sub _setup_base_limit {
    my $self = shift;

    my $base_limit = $self->build->calculate_base_limit_from_coverage;
    if ( defined $base_limit ) {
        $self->_base_limit($base_limit);
    }

    return 1;
}

sub _is_there_a_base_limit_and_has_it_been_exceeded {
    my $self = shift;

    return if not defined $self->_base_limit; # ok

    my $metrics = $self->_metrics;
    if ( not defined $metrics->{bases} ) {
        $self->error_message("No bases metric found in read processor metric when trying to determine if the base limit has been exceeded.");
        return;
    }

    if ( ($self->_base_limit - $metrics->{bases}) <= 0 ) {
        return 1;
    }

    return;
}

sub _update_metrics {
    my $self = shift;

    $self->status_message("Updating metrics...");

    my $metrics_file = $self->_metrics_file;
    $self->status_message("Getting metrics from file: $metrics_file");
    if ( not -s $metrics_file ) {
        $self->error_message("No metrics file ($metrics_file) from read processor command.");
        return;
    }

    my  $fh = eval {
        Genome::Sys->open_file_for_reading($metrics_file);
    };
    if ( not $fh ) {
        $self->error_message("Cannot open coverage metrics file ($metrics_file): $@");
        return;
    }

    my %metrics_from_file;
    while ( my $line = $fh->getline ) {
        chomp $line;
        my ($metric, $val) = split('=', $line);
        $self->status_message($metric.' from metrics file is '.$val);
        $metrics_from_file{$metric} = $val;
    }

    my $metrics = $self->_metrics;
    for my $metric (qw/ bases count /) { # these are reauired. There may be more...
        if ( not defined $metrics_from_file{$metric} ) {
            $self->error_message("Metric ($metric) not found in metrics file");
            return;
        }
        $metrics->{$metric} += $metrics_from_file{$metric};
        $self->status_message("Updated $metric to ".$metrics->{$metric});
    }
    $self->_metrics($metrics);

    $self->status_message('OK...Updated metrics');

    return 1;
}
#<>#

sub _instrument_data_qual_type_in {
    my ( $self, $instrument_data ) = @_;
    
    if ( $instrument_data->class eq 'Genome::InstrumentData::Solexa' ) {
        return 'sanger' if -s $instrument_data->bam_path;
        return 'illumina';
    }

    if ( $instrument_data->class eq 'Genome::InstrumentData::Imported' ) {
        return 'sanger';
    }

    return;
}

sub _process_instrument_data {
    my ($self, $instrument_data) = @_;

    # Inst data quality type
    my $qual_type_in = $self->_instrument_data_qual_type_in( $instrument_data );
    unless ( $qual_type_in ) {
        $self->error_message( "Can't determine quality type in for inst data, ID: ".$instrument_data->id );
        return;
    }
    my $qual_type_out = 'sanger';

    $self->status_message('Processing: '.join(' ', $instrument_data->class, $instrument_data->id, $qual_type_in) );

    # In/out files
    my @input_files = $self->_fastq_files_from_solexa($instrument_data)
        or return;
    my @output_files = $self->build->read_processor_output_files_for_instrument_data($instrument_data)
        or return;

    # Fast qual command
    my $read_processor = $self->processing_profile->read_processor;
    my $fast_qual_class;
    my %fast_qual_params = (
        input => [ map { $_.':type='.$qual_type_in } @input_files ],
        output => [ map { $_.':type=sanger' } @output_files ],
        metrics_file_out => $self->_metrics_file,
    );

    if ( not defined $read_processor and not defined $self->_base_limit ) {
        # Run through the base fast qual command. This will rm quality headers and get metrics
        $fast_qual_class = 'Genome::Model::Tools::Sx';
    }
    else {
        # Got multiple commands, use pipe
        $fast_qual_class = 'Genome::Model::Tools::Sx::Pipe';
        my @commands;
        if ( defined $self->_base_limit ) { # coverage limit by bases
            my $metrics = $self->_metrics;
            my $current_base_limit = $self->_base_limit - $metrics->{bases};
            unshift @commands, 'limit by-coverage --bases '.$current_base_limit;
        }

        if ( defined $read_processor ) { # read processor from pp
            unshift @commands, $read_processor;
        }

        $fast_qual_params{commands} = join(' | ', @commands);
    }

    # Create and execute
    $self->status_message('Fast qual class: '.$fast_qual_class);
    $self->status_message('Fast qual params: '.Dumper(\%fast_qual_params));
    my $fast_qual_command = $fast_qual_class->create(%fast_qual_params);
    if ( not defined $fast_qual_command ) {
        $self->error_message("Cannot create fast qual command.");
        return;
    }
    my $rv = $fast_qual_command->execute;
    if ( not $rv ) {
        $self->error_message("Cannot execute fast qual command.");
        return;
    }

    $self->status_message('Execute OK');

    $self->_update_metrics
        or return;

    return 1;
}
#<>#

#< Files From Instrument Data >#
sub _fastq_files_from_solexa {
    my ($self, $inst_data) = @_;

    $self->status_message("Getting fastq files from solexa instrument data ".$inst_data->id);

    my @fastq_files;

    if ( not $inst_data->bam_path ) {
        my $archive_path = $inst_data->archive_path;
        $self->status_message("No bam path for instrument dataq, verifying archive path: $archive_path");
        unless ( -s $archive_path ) {
            $self->error_message(
                "No archive path for instrument data (".$inst_data->id.")"
                );
            return;
        }
        $self->status_message("Archive path OK");

        # tar to tempdir
        my $tempdir = $self->_tempdir;
        my $inst_data_tempdir = $tempdir.'/'.$inst_data->id;
        $self->status_message("Creating temp dir: $inst_data_tempdir");
        Genome::Sys->create_directory($inst_data_tempdir)
            or die;
        $self->status_message("Temp dir OK");

        my $tar_cmd = "tar zxf $archive_path -C $inst_data_tempdir";
        $self->status_message("Running tar: $tar_cmd");
        unless ( Genome::Sys->shellcmd(cmd => $tar_cmd) ) {
            $self->error_message("Can't extract archive file $archive_path with command '$tar_cmd'");
            return;
        }
        $self->status_message("Tar OK");

        # glob files
        $self->status_message("Checking fastqs we're dumped...");
        @fastq_files = glob $inst_data_tempdir .'/*';
        unless ( @fastq_files ) {
            $self->error_message("Extracted archive path ($archive_path), but no fastqs found.");
            return;
        }
        $self->status_message('Fastq files from archive OK:'.join(", ", @fastq_files));
    }
    else {
        unless ( -s $inst_data->bam_path ) {
            $self->error_message("No bam file found or file is zero size: ".$inst_data->bam_path);
            return;
        }
        $self->status_message("Attempting to get fastqs from bam");

        my $tempdir = $self->_tempdir;
        my $inst_data_tempdir = $tempdir.'/'.$inst_data->id;

        @fastq_files = $inst_data->dump_fastqs_from_bam( directory => $tempdir );

        $self->status_message('Fastq files from bam OK:'.join(", ", @fastq_files));
    }

    return @fastq_files;
}

#<>#

1;

#$HeadURL$
#$Id$
