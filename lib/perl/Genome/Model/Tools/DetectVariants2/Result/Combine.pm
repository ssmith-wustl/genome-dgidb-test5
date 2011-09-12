package Genome::Model::Tools::DetectVariants2::Result::Combine;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Result::Combine {
    is  => ['Genome::SoftwareResult::Stageable'],
    has_input => [
        input_a_id => {
            is => 'Text',
        },
        input_b_id => {
            is => 'Text',
        },
    ],
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'variant_type',
            doc => 'variant type that this module operates on, overload this in submodules accordingly',
        },
    ],
    has_optional => [
        input_a => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            id_by => 'input_a_id',
        },
        input_b => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            id_by => 'input_b_id',
        },
        input_directory_a => {
            is => 'Text',
            via => 'input_a',
            to => 'output_dir',
        },
        input_directory_b => {
            is => 'Text',
            via => 'input_b',
            to => 'output_dir',
        },
    ],
};

sub create {
    my $self = shift;
    unless($self->_validate_inputs) {
        die $self->error_message('Failed to validate inputs.');
    }

    unless($self->_create_directories) {
        die $self->error_message('Failed to create directories.');
    }

    unless($self->_combine_variants){
        die $self->error_message('Failted to combine variants');
    }
    unless($self->_validate_output) {
        die $self->error_message('Failed to validate output.');
    }
    return 1;
}

sub _combine_variants {
    die "overload this function to do work";
}

sub _validate_inputs {
    my $self = shift;

    my $input_dir = $self->input_directory_a;
    unless (Genome::Sys->check_for_path_existence($input_dir)) {
        $self->error_message("input_directory_a input $input_dir does not exist");
        return;
    }
    $input_dir = $self->input_directory_b;
    unless (Genome::Sys->check_for_path_existence($input_dir)) {
        $self->error_message("input_directory_b input $input_dir does not exist");
        return;
    }

    return 1;
}

sub _validate_output {
    my $self = shift;
    my $variant_type = $self->_variant_type;
    my $input_a_file = $self->input_directory_a."/".$variant_type.".hq.bed";
    my $input_b_file = $self->input_directory_b."/".$variant_type.".hq.bed";
    my $hq_output_file = $self->output_dir."/".$variant_type.".hq.bed";
    my $lq_output_file = $self->output_dir."/".$variant_type.".lq.bed";
    my $input_total = $self->line_count($input_a_file) + $self->line_count($input_b_file);
    my $output_total = $self->line_count($hq_output_file) + $self->line_count($lq_output_file);
    unless(($input_total - $output_total) == 0){
        die $self->error_message("Combine operation in/out check failed. Input total: $input_total \toutput total: $output_total");
    }
    return 1;
}

sub has_version {
    return 1;
}

1;
