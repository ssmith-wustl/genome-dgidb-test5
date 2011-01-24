package Genome::Model::Tools::DetectVariants2::Filter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Filter {
    is  => 'Command',
    has => [
        variant_file => {
           type => 'String',
           is_input => 1,
           doc => 'input variant file, means tumor usually',
        },
        output_file => {
            type => 'String',
            is_input => 1,
            is_output => 1,
            doc => 'File name in which to write output',
        },
        control_variant_file => {
            type => 'String',
            is_input => 1,
            is_optional => 1,
            doc => 'control input variant file, means normal usually',
        },
        version => {
            is_input => 1,
            is => 'Version',
            is_optional => 1,
            doc => 'The version of the variant filter to use.',
        },
        extra_output_file => {
            type => 'String',
            is_input => 1,
            is_optional => 1,
            doc => 'extra output file ceated by the tools',
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through if the output_file is already present. Useful for pipelines.',
        },
        lsf_resource => {
            is_param => 1,
            is_optional => 1,
            default_value => 'rusage[mem=4000] select[type==LINUX64] span[hosts=1]',
        },
        lsf_queue => {
            is_param => 1,
            is_optional => 1,
            default_value => 'long',
        },
    ]
};

sub help_brief {
    "A selection of variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt filter-variants ...
EOS
}

sub help_detail {
    return <<EOS 
Tools to run variant detectors with a common API and output their results in a standard format.
EOS
}


sub create {
    my $self = shift;
       
    unless($self->_validate_file) {
        die $self->error_message('Failed to validate file.');
    }
    
    return 1;
}


sub _validate_file {
    my $self = shift;

    my $input_file = $self->variant_file;
    unless (Genome::Sys->check_for_path_existence($input_file)) {
        $self->error_message("variant file input $input_file does not exist");
        return;
    }

    my $output_file = $self->output_file;
    unless(Genome::Sys->validate_file_for_writing($output_file)) {
        $self->error_message("output file $output_file is not writable.");
        return;
    }
    
    my $c_input_file = $self->control_variant_file;
    if ($c_input_file) {
        unless (Genome::Sys->check_for_path_existence($c_input_file)) {
            $self->error_message("control variant file input $c_input_file does not exist");
            return;
        }
    }

    my $extra_out_file = $self->extra_output_file;
    if ($extra_out_file) {
        unless (Genome::Sys->validate_file_for_writing($extra_out_file)) {
            $self->error_message("extra output file $extra_out_file is not writable.");
            return;
        }
    }

    return 1;
}

1;
