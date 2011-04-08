package Genome::Model::Tools::DetectVariants2::Combine;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine {
    is  => ['Genome::Model::Tools::DetectVariants2::Base'],
    is_abstract => 1,
    has => [
        input_directory_a => {
            type => 'String',
            is_input => 1,
            doc => 'input directory a, find <variant_type>.hq.bed in here to combine with the same in dir b',
        },    
        input_directory_b => {
            type => 'String',
            is_input => 1,
            doc => 'input directory b, find <variant_type>.hq.bed in here to combine with the same in dir a',
        },
    ],
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'variant_type',
            doc => 'variant type that this module operates on, overload this in submodules accordingly',
        },
    ],
};

sub help_brief {
    "A selection of variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 combine ...
EOS
}

sub help_detail {
    return <<EOS 
Tools to run variant detectors with a common API and output their results in a standard format.
EOS
}


sub execute {
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
    my $hq_output_file = $self->output_directory."/".$variant_type.".hq.bed";
    my $lq_output_file = $self->output_directory."/".$variant_type.".lq.bed";
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
