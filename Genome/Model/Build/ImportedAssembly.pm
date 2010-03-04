package Genome::Model::Build::ImportedAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedAssembly {
    is => 'Genome::Model::Build',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    unless ($self->model->type_name eq 'imported assembly') {
	$self->error_message("Model type must be imported assembly, not ".$self->model_type_name);
	$self->delete;
	return;
    }
    #TRACKING ALREADY EXISTING ASSEMBLIES SO DIRECTORY SHOULD ALREADY BE THERE
    unless (-d $self->model->data_directory) {
	$self->error_message("Failed to find assembly directory: ".$self->model->data_directory);
	return;
    }

    $self->status_message("Your assembly has been tracked successfully");

    return $self;
}

1;
