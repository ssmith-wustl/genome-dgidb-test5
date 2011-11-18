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
    return "-R 'select[type==LINUX64 && tmp>25000] rusage[tmp=25000] span[hosts=1]'"
}

sub _tempdir {
    my $self = shift;

    unless ( $self->{_tempdir} ) {
        $self->{_tempdir} = Genome::Sys->base_temp_directory;
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

    $self->status_message('Process instrument data');
    INST_DATA: for my $instrument_data ( @instrument_data ) {
        my $process_ok = $self->_process_instrument_data($instrument_data);
        return if not $process_ok;
        if ( $self->_is_there_a_base_limit_and_has_it_been_exceeded ) {
            $self->status_message('Reached base limit: '.$self->_base_limit);
            last INST_DATA;
        }
    }
    $self->status_message('Process instrument data...OK');

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

sub _process_instrument_data {
    my ($self, $instrument_data) = @_;
    $self->status_message('Process: '.join(' ', map { $instrument_data->$_ } (qw/ class id/)));

    # Output files
    my @output_files = $self->build->read_processor_output_files_for_instrument_data($instrument_data);
    return if not @output_files;
    my $output;
    if ( @output_files == 1 ) {
        $output = $output_files[0].':type=sanger:mode=a';
    }
    elsif ( @output_files == 2 ) {
        $output = $output_files[0].':name=fwd:type=sanger:mode=a,'.$output_files[1].':name=rev:type=sanger:mode=a';
    }
    else {
        $self->error_message('Cannot handle more than 2 output files');
        return;
    }

    # Input files
    my @inputs;
    if ( my $bam = eval{ $instrument_data->bam_path } ) {
        @inputs = ( $bam.':type=bam' );
    }
    elsif ( my $sff_file = eval{ $instrument_data->sff_file } ) {
        @inputs = ( $sff_file.':type=sff' );
    }
    elsif ( my $archive = eval{ $instrument_data->archive_path; } ){
        my $qual_type = 'sanger'; # imported will be sanger; check solexa
        if ( $instrument_data->can('resolve_quality_converter') ) {
            my $converter = eval{ $instrument_data->resolve_quality_converter };
            if ( not $converter ) {
                $self->error_message('No quality converter for instrument data '.$instrument_data->id);
                return;
            }
            elsif ( $converter eq 'sol2sanger' ) {
                $self->error_message('Cannot process old illumina data! Instrument data '.$instrument_data->id);
                return;
            }
            $qual_type = 'illumina';
        }
        my $instrument_data_tempdir = $self->_tempdir.'/'.$instrument_data->id;
        my $create_dir = Genome::Sys->create_directory($instrument_data_tempdir);
        if ( not $create_dir or not -d $instrument_data_tempdir ) {
            $self->error_message('Failed to make temp directory for instrument data!');
            return;
        }
        my $cmd = "tar -xzf $archive --directory=$instrument_data_tempdir";
        my $tar = Genome::Sys->shellcmd(cmd => $cmd);
        if ( not $tar ) {
            $self->error_message('Failed extract archive for instrument data '.$instrument_data->id);
            return;
        }
        my @input_files = grep { not -d } glob("$instrument_data_tempdir/*");
        if ( not @input_files ) {
            $self->error_message('No fastqs from archive from instrument data '.$instrument_data->id);
            return;
        }
        @inputs = map { $_.':type='.$qual_type } @input_files;
    }
    else {
        $self->error_message('Failed to get bam, sff or archived fastqs from instrument data: '.$instrument_data->id);
        return;
    }

    # Sx read processor
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

    my @sx_cmd_parts = map { 'gmt sx '.$_ } @read_processor_parts;
    $sx_cmd_parts[0] .= ' --input '.join(',', @inputs);
    $sx_cmd_parts[$#read_processor_parts] .= ' --output '.$output;
    $sx_cmd_parts[$#read_processor_parts] .= ' --output-metrics '.$self->_metrics_file;

    # Run
    my $sx_cmd = join(' | ', @sx_cmd_parts);
    my $rv = eval{ Genome::Sys->shellcmd(cmd => $sx_cmd); };
    if ( not $rv ) {
        $self->error_message('Failed to execute gmt sx command: '.$@);
        return;
    }

    return 1;
}
#<>#

1;

