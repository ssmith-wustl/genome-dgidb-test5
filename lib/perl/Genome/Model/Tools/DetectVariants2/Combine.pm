package Genome::Model::Tools::DetectVariants2::Combine;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine {
    is  => ['Genome::Model::Tools::DetectVariants2::Base'],
    is_abstract => 1,
    has => [
        variant_file_a => {
            type => 'String',
            is_input => 1,
            is_optional => 0,
            doc => 'input variant file a, to be combined with file b',
        },
        variant_file_b => {
            type => 'String',
            is_input => 1,
            is_optional => 0,
            doc => 'input variant file b, to be combined with file a',
        },
        output_file => {
            type => 'String',
            is_input => 1,
            is_output => 1,
            doc => 'File in which to write output',
        },
    ]
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

    my $input_file = $self->variant_file_a;
    unless (Genome::Sys->check_for_path_existence($input_file)) {
        $self->error_message("variant_file_a input $input_file does not exist");
        return;
    }
    $input_file = $self->variant_file_b;
    unless (Genome::Sys->check_for_path_existence($input_file)) {
        $self->error_message("variant_file_b input $input_file does not exist");
        return;
    }
    my $output_file = $self->output_file;
    unless(Genome::Sys->validate_file_for_writing($output_file)) {
        $self->error_message("output file $output_file is not writable.");
        return;
    }
    
    
    return 1;
}

sub has_version {
    return 1;
}

1;
