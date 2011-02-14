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
    unless($self->_validate_file) {
        die $self->error_message('Failed to validate file.');
    }

    unless($self->_combine_variants){
        die $self->error_message('Failted to combine variants');
    }
    return 1;
}

sub _combine_variants {
    die "overload this function to do work";
}

sub _validate_file {
    my $self = shift;

    my $input_dir = $self->input_directory_a;
    unless (Genome::Sys->check_for_path_existence($input_dir)) {
        $self->error_message("variant_file_a input $input_dir does not exist");
        return;
    }
    $input_dir = $self->input_directory_b;
    unless (Genome::Sys->check_for_path_existence($input_dir)) {
        $self->error_message("variant_file_b input $input_dir does not exist");
        return;
    }
    
    return 1;
}

sub has_version {
    return 1;
}

1;
