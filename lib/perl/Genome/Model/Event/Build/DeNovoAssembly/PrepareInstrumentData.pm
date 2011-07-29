package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData;

use strict;
use warnings;

use Genome;

require File::Temp;

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

    $self->status_message('Prepare instrument data for '.$self->build->description);

    $self->status_message('Verify instrument data...');
    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("Failed to prepare instrument data. Build does not have any.");
        return;
    }
    $self->status_message('Verify instrument data...OK');

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
    INST_DATA: for my $instrument_data ( @instrument_data ) {
        my $process_ok = $self->_process_instrument_data($instrument_data);
        return if not $process_ok;
        if ( $self->_is_there_a_base_limit_and_has_it_been_exceeded ) {
            $self->status_message('Reached base limit: '.$self->_base_limit);
            last INST_DATA;
        }
    }
    $self->status_message('Processing instrument data...OK');

    $self->status_message('Verify assembler input files');
    @existing_assembler_input_files = $self->build->existing_assembler_input_files;
    if ( not @existing_assembler_input_files ) {
        $self->error_message('No assembler input files were created!');
        return;
    }
    $self->status_message('Verify assembler input files...OK');

    $self->status_message('Prepare instrument data...OK');

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

    $self->status_message('Current base limit: '.$self->_base_limit);

    $self->status_message('Updating metrics...');
    my $metrics_file = $self->_metrics_file;
    $self->status_message("Metrics file: $metrics_file");
    if ( not -s $metrics_file ) {
        $self->error_message("No metrics file ($metrics_file) from read processor command.");
        return;
    }

    my  $fh = eval { Genome::Sys->open_file_for_reading($metrics_file); };
    if ( not $fh ) {
        $self->error_message("Failed to open metrics file ($metrics_file): $@");
        return;
    }

    my $metrics = $self->_metrics;
    my %metrics_from_file;
    while ( my $line = $fh->getline ) {
        chomp $line;
        my ($metric, $val) = split('=', $line);
        $self->status_message($metric.' from metrics file is '.$val);
        $metrics_from_file{$metric} = $val;
        $metrics->{$metric} += $metrics_from_file{$metric};
        $self->status_message("Updated $metric to ".$metrics->{$metric});
    }

    if ( not defined $metrics->{bases} ) {
        Carp::confess('No bases found in metrics');
    }

    $self->_metrics($metrics);
    $self->status_message('OK...Updated metrics');

    if ( ($self->_base_limit - $metrics->{bases}) <= 0 ) {
        return 1;
    }

    return;
}
#<>#

sub _instrument_data_qual_type_in {
    my ( $self, $instrument_data ) = @_;
    
    if ( $instrument_data->class eq 'Genome::InstrumentData::Solexa' ) {
        return 'sanger' if $instrument_data->bam_path and -s $instrument_data->bam_path;
        return 'illumina';
    }

    if ( $instrument_data->class eq 'Genome::InstrumentData::Imported' ) {
        return 'sanger';
    }

    if ( $instrument_data->class eq 'Genome::InstrumentData::454' ) {
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
    my $fastq_method = '_fastq_files_from_'.$instrument_data->sequencing_platform;
    my @input_files = $self->$fastq_method($instrument_data)
        or return;
    my @output_files = $self->build->read_processor_output_files_for_instrument_data($instrument_data)
        or return;

    my $read_processor = $self->processing_profile->read_processor;
    my @read_processor_parts = split(/\s+\|\s+/, $read_processor);

    if ( defined $self->_base_limit ) { # coverage limit by bases
        my $metrics = $self->_metrics;
        #my $current_base_limit = $self->_base_limit - $metrics->{bases};
        my $current_base_limit = $self->_base_limit;
        $current_base_limit -= $metrics->{bases} if exists $metrics->{bases};
        $self->status_message("Limiting bases by base count of $current_base_limit");
        push @read_processor_parts, 'limit by-bases --bases '.$current_base_limit;
    }

    if ( not @read_processor_parts ) { # essentially a copy, but w/ metrics
        @read_processor_parts = ('');
    }

    # Fast qual command
    my @sx_cmd_parts = map { 'gmt sx '.$_ } @read_processor_parts;
    $sx_cmd_parts[0] .= ' --input '.join(',', map { $_.':type='.$qual_type_in } @input_files);
    my $output;
    if ( @output_files == 1 ) {
        $output = $output_files[0].':type=sanger';
    }
    elsif ( @output_files == 2 ) {
        $output = $output_files[0].':name=fwd:type=sanger,'.$output_files[1].':name=rev:type=sanger';
    }
    else {
        $self->error_message('Cannot handle more than 2 output files');
        return;
    }
    $sx_cmd_parts[$#read_processor_parts] .= ' --output '.$output;
    $sx_cmd_parts[$#read_processor_parts] .= ' --output-metrics '.$self->_metrics_file;

    my $sx_cmd = join(' | ', @sx_cmd_parts);
    my $rv = eval{ Genome::Sys->shellcmd(cmd => $sx_cmd); };
    if ( not $rv ) {
        $self->error_message('Failed to execute gmt sx command: '.$@);
        return;
    }

    $self->status_message('Process Instrument data...OK');

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

sub _fastq_files_from_454 {
    my ( $self, $inst_data ) = @_;

    $self->status_message( "Getting fastq files fro 454 inst data: ".$inst_data->id );

    my @fastq_files = $inst_data->dump_sanger_fastq_files; #Dumps to temp dir

    unless ( @fastq_files ) {
        $self->error_message( "Could not dump fastq files from inst data: ".$inst_data->id );
        return;
    }

    return @fastq_files;
}

#<>#

1;

#$HeadURL$
#$Id$
