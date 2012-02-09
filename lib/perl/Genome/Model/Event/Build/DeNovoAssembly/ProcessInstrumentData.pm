package Genome::Model::Event::Build::DeNovoAssembly::ProcessInstrumentData;

use strict;
use warnings;

use Genome;

require File::Temp;

class Genome::Model::Event::Build::DeNovoAssembly::ProcessInstrumentData {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub shortcut {
    my $self = shift;

    my %params = $self->build->read_processor_params_for_instrument_data($self->instrument_data);

    my $result = Genome::InstrumentData::SxResult->get_with_lock(%params);

    if($result) {
        $self->status_message('Using existing result ' . 
            $result->__display_name__);
        return $self->link_result_to_build($result);
    }
    else {
        return;
    }
}

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

sub execute {
    my $self = shift;
    my $instrument_data = $self->instrument_data;

    $self->status_message('Process instrument data '.$instrument_data->__display_name__ .' for '.$self->build->description);

    my %params = 
        $self->build->read_processor_params_for_instrument_data($instrument_data);

    my $result = Genome::InstrumentData::SxResult->get_or_create(%params);

    $self->link_result_to_build($result);

    $self->status_message('Process instrument data...OK');

    return 1;
}

sub link_result_to_build {
    my $self = shift;
    my $result = shift;

    $result->add_user(label => 'processed_reads', user => $self->build);

    foreach my $output_file ($result->read_processor_output_files) {
        Genome::Sys->create_symlink($result->output_dir.'/'.$output_file, $self->build->data_directory.'/'.$output_file);
    }

    Genome::Sys->create_symlink(
        $result->output_dir.'/'.
        $result->read_processor_output_metric_file,
        $self->build->data_directory.'/'.
        $result->read_processor_output_metric_file);

    Genome::Sys->create_symlink(
        $result->output_dir.'/'.
        $result->read_processor_input_metric_file,
        $self->build->data_directory.'/'.
        $result->read_processor_input_metric_file);

    return 1;
}

#<>#

1;

