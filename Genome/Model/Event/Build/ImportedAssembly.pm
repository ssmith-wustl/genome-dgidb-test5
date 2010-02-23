package Genome::Model::Event::Build::ImportedAssembly;

use strict;
use warnings;

use Genome;


class Genome::Model::Event::Build::ImportedAssembly{
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;
    my $model = $self->model;
    #TRACKING ALREADY EXISTING ASSEMBLIES SO DIRECTORY SHOULD ALREADY BE THERE
    unless (-d $self->build->data_directory) {
	$self->error_message("Failed to find assembly data directory");
	return;
    }

    $self->status_message($self->build->data_directory." exists");

    return 1;
}

1;
