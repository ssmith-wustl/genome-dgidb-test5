package Genome::Model::Event::Build::DeNovoAssembly::ProcessInstrumentData;

use strict;
use warnings;

use Genome;

require File::Temp;

class Genome::Model::Event::Build::DeNovoAssembly::ProcessInstrumentData {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub bsub_rusage {
    my $self = shift;
    my $read_processor = $self->processing_profile->read_processor;
    my $tmp_space = 25000;
    if ( $read_processor and $read_processor =~ /quake|eulr/i ) {
        # Request memory for quake and eulr
        my $mem = 32000;
        $tmp_space = 200000;
        return "-R 'select[type==LINUX64 && mem>$mem && tmp>$tmp_space] rusage[mem=$mem:tmp=$tmp_space] span[hosts=1]' -M $mem"."000";
    }

    return "-R 'select[type==LINUX64 && tmp>$tmp_space] rusage[tmp=$tmp_space] span[hosts=1]'"
}

sub _input_metrics_file { 
    my $self = shift;
    return $self->build->data_directory.'/metrics.input.'.$self->instrument_data->id.'.txt';
}

sub _output_metrics_file {
    my $self = shift;
    return $self->build->data_directory.'/metrics.output.'.$self->instrument_data->id.'.txt';
}

sub execute {
    my $self = shift;
    my $instrument_data = $self->instrument_data;

    $self->status_message('Process instrument data '.$instrument_data->__display_name__ .' for '.$self->build->description);

#TODO: need to move    $self->_setup_base_limit;

    $self->status_message('Process instrument data');
    my $process_ok = $self->_process_instrument_data;
    return if not $process_ok;
#TODO move to separate class        last INST_DATA if $self->_has_base_limit_been_reached;

    $self->status_message('Process instrument data...OK');

    $self->status_message('Verify assembler input files');
    my @existing_assembler_input_files = $self->build->existing_assembler_input_files;
    if ( not @existing_assembler_input_files ) {
        $self->error_message('No assembler input files were created!');
        return;
    }
    $self->status_message('Verify assembler input files...OK');

#TODO must be moved to after all instrument data is processed
=cut
    my $reads_attempted = $self->_input_count;
    my $reads_processed = $self->_output_count;
    my $reads_processed_success = ( $reads_attempted ? sprintf('%0.3f', $reads_processed / $reads_attempted) : 0);
    $self->build->add_metric(name => 'reads attempted', value => $reads_attempted);
    $self->build->add_metric(name => 'reads processed', value => $reads_processed);
    $self->build->add_metric(name => 'reads processed success', value => $reads_processed_success);
    $self->status_message('Reads attempted: '.$reads_attempted);
    $self->status_message('Reads processed: '.$reads_processed);
    $self->status_message('Reads processed success: '.($reads_processed_success * 100).'%');
=cut

    $self->status_message('Prepare instrument data...OK');
    return 1;
}

#TODO move to separate class
=cut
sub _setup_base_limit {
    my $self = shift;

    my $base_limit = $self->build->calculate_base_limit_from_coverage;
    return 1 if not defined $base_limit;

    $self->status_message('Setting base limit to: '.$base_limit);
    $self->_original_base_limit($base_limit);
    $self->_base_limit($base_limit);

    return 1;
}
=cut

#TODO: move elsewhere
=cut
sub _update_metrics {
    my $self = shift;
    $self->status_message('Update metrics...');

    for my $type (qw/ input output /) {
        my $metrics_file_method = '_'.$type.'_metrics_file';
        my $metrics_file = $self->$metrics_file_method;
        $self->status_message(ucfirst($type)." file: $metrics_file");
        if ( not -s $metrics_file ) {
            Carp::confess("No metrics file ($metrics_file) from read processor command.");
        }

        my  $fh = eval { Genome::Sys->open_file_for_reading($metrics_file); };
        if ( not $fh ) {
            Carp::confess("Failed to open metrics file ($metrics_file): $@");
        }

        while ( my $line = $fh->getline ) {
            chomp $line;
            my ($name, $val) = split('=', $line);
            my $metric_method = '_'.$type.'_'.$name;
            my $metric = $self->$metric_method;
            my $new_metric = $metric + $val;
            $self->$metric_method($new_metric);
            $self->status_message("Update $type $name from $metric to $new_metric");
        }
    }

    $self->status_message('Update metrics...OK');
    return 1;
}
=cut

#TODO: move elsewhere
=cut
sub _has_base_limit_been_reached {
    my $self = shift;

    return if not defined $self->_base_limit;

    $self->status_message('Original base limit: '.$self->_original_base_limit);
    $self->status_message('Bases processed: '.$self->_output_bases);
    my $current_base_limit = $self->_original_base_limit - $self->_output_bases;
    $self->_base_limit($current_base_limit);
    if ( $current_base_limit <= 0 ) {
        $self->status_message('Reached base limit. Stop processing!');
        return 1;
    }
    $self->status_message('New base limit: '.$self->_base_limit);

    $self->status_message('Base limit not reached. Continue processing.');
    return;
}
=cut

sub _process_instrument_data {
    my ($self) = @_;
    my $instrument_data = $self->instrument_data;
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
    my $is_paired_end = eval{ $instrument_data->is_paired_end; };
    my $input_cnt = ( $is_paired_end ? 2 : 1 );
    my @inputs;
    if ( my $bam = eval{ $instrument_data->bam_path } ) {
        @inputs = ( $bam.':type=bam:cnt='.$input_cnt );
    }
    elsif ( my $sff = eval{ $instrument_data->sff_file } ) {
        @inputs = ( $sff.':type=sff:cnt='.$input_cnt );
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
        my $instrument_data_tempdir = File::Temp::tempdir(CLEANUP => 1);
        if ( not -d $instrument_data_tempdir ) {
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

=cut
    if ( defined $self->_base_limit ) { # coverage limit by bases
        my $current_base_limit = $self->_base_limit;
        $self->status_message("Limiting bases by base count of $current_base_limit");
        push @read_processor_parts, 'limit by-bases --bases '.$current_base_limit;
    }
=cut

    if ( not @read_processor_parts ) { # essentially a copy, but w/ metrics
        @read_processor_parts = ('');
    }

    my @sx_cmd_parts = map { 'gmt sx '.$_ } @read_processor_parts;
    $sx_cmd_parts[0] .= ' --input '.join(',', @inputs);
    $sx_cmd_parts[0] .= ' --input-metrics '.$self->_input_metrics_file;
    $sx_cmd_parts[$#read_processor_parts] .= ' --output '.$output;
    $sx_cmd_parts[$#read_processor_parts] .= ' --output-metrics '.$self->_output_metrics_file;

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

