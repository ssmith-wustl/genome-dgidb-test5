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

    unless ($self->model->type_name eq 'virome screen') {
	$self->error_message("Invalid model type for virome screening");
	$self->delete;
	return;
    }

    return $self;
}

sub screen_directory {
    my $self = shift;
    return $self->data_directory.'/virome_screen';
}

sub get_barcode_file {
    my $self = shift;
    return $self->barcode_file;
}

sub get_log_file {
    my $self = shift;
    return $self->log_file;
}

1;
