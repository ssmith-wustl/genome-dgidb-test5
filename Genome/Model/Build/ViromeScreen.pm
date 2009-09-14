package Genome::Model::Build::ViromeScreen;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ViromeScreen {
    is => 'Genome::Model::Build',
#   has => [ ],
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

    #SOME VERIFICATION OF DATA DATA DIRECTORY
#    unless ($self->model->data_directory) {
#	$self->error_message("Data directory for model does not exist");
#	return;
#    }
    return $self;
}

1;
