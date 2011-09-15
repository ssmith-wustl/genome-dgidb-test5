package Genome::Model::Tools::DetectVariants2::Combine;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine {
    is  => ['Genome::Command::Base'],
    is_abstract => 1,
    has_input => [
        input_a_id => {
            is => 'Text',
        },
        input_b_id => {
            is => 'Text',
        },
        output_directory => {
            is => 'Text',
            is_output => 1,
        },
    ],
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'variant_type',
            doc => 'variant type that this module operates on, overload this in submodules accordingly',
        },
    ],
    has_param => [
        lsf_queue => {
            default => 'apipe',
        },
    ],
    has_optional => [
        _result_id => {
            is => 'Text',
            is_output => 1,
        },
        _result_class => {
            is => 'Text',
            is_output => 1,
        },
        _result => {
            is => 'UR::Object',
            id_by => '_result_id', id_class_by => '_result_class',
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

sub result_class {
    my $self = shift;
    my $result_class = $self->class;
    $result_class =~ s/DetectVariants2::Combine/DetectVariants2::Result::Combine/;
    return $result_class;
}

sub shortcut {
    my $self = shift;

    my ($params) = $self->params_for_result;
    my $result_class = $self->result_class;
    my $result = $result_class->get_or_create(%$params);
    unless($result) {
        $self->status_message('No existing result found.');
        return;
    }

    $self->_result($result);
    $self->status_message('Using existing result ' . $result->__display_name__);
    $self->_link_to_result;

    return 1;
}

sub execute {
    my $self = shift;

    my ($params) = $self->params_for_result;
    my $result_class = $self->result_class;
    my $result = $result_class->get_or_create(%$params);

    unless($result) {
        die $self->error_message('Failed to create generate result!');
    }

    if(-e $self->output_directory) {
        unless(readlink($self->output_directory) eq $result->output_dir) {
            die $self->error_message('Existing output directory ' . $self->output_directory . ' points to a different location!');
        }
    }

    $self->_result($result);
    $self->status_message('Generated result.');
    $self->_link_to_result;

    return 1;
}

sub params_for_result {
    my $self = shift;

    my %params = (
        input_a_id => $self->input_a_id,
        input_b_id => $self->input_b_id,
        subclass_name => $self->_result_class,
        test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef,
    );

    return \%params;
}

sub _link_to_result {
    my $self = shift;

    my $result = $self->_result;
    return unless $result;

    if (-e $self->output_directory) {
        return;
    }
    else {
        return Genome::Sys->create_symlink_and_log_change($result, $result->output_dir, $self->output_directory);
    }
}

1;
