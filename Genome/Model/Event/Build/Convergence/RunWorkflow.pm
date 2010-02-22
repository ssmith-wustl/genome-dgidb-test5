package Genome::Model::Event::Build::Convergence::RunWorkflow;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::Convergence::RunWorkflow {
    is          => ['Genome::Model::Event'],
};

sub execute {
    my $self = shift;

    # Verify the model and build
    my $model = $self->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        return;
    }
    my $build = $self->build;
    unless ($build) {
        $self->error_message("Failed to get a build object!");
        return;
    }
    
    # Get the associated models
    my @members = $build->members;
    unless(scalar @members) {
        $self->error_message("Need at least one member model to run the workflow.");
        return;
    } 

    my $data_directory = $self->build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        return;
    }

    my $workflow = Genome::Model::Tools::Convergence::Pipeline->create(
        build_id => $build->id,
    );

    unless ($workflow) {
        $self->error_message("Failed to create workflow!");
        return;
    }

    $workflow->execute();

    return 1;
}


1;
