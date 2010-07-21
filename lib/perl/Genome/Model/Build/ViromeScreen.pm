package Genome::Model::Build::ViromeScreen;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ViromeScreen {
    is => 'Genome::Model::Build',
    has => [
        barcode_file => {
            via => 'attributes',
            to => 'value',
            where => [property_name => 'barcode_file'],
            is_mutable => 1,
        },
        log_file => {
            via => 'attributes',
            to => 'value',
            where => [property_name => 'log_file'],
            is_mutable => 1,
        },
    ]
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
	    or return;

    # this is now set on the model, and copied here
    $self->barcode_file($self->model->barcode_file);
    unless (-e $self->barcode_file) {
        $self->error_message("Failed to find barcode file: " . $self->barcode_file);
        $self->delete;
        return;
    }

    # builds all have log files, why do we have this?
    $self->log_file($self->data_directory . '/log_file') unless $self->log_file;

    return $self;
}

sub screen_directory {
    my $self = shift;
    return $self->data_directory.'/virome_screen';
}

sub get_barcode_file { #?
    my $self = shift;
    return $self->barcode_file;
}

sub get_log_file { #?
    my $self = shift;
    return $self->log_file;
}

1;
