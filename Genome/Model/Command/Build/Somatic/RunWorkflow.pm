package Genome::Model::Command::Build::Somatic::RunWorkflow;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::Build::Somatic::RunWorkflow {
    is => ['Genome::Model::Event'],
};

sub help_brief {
    "Runs the somatic pipeline on the latest build of the normal and tumor models for this somatic model"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given Somatic model.
EOS
}

sub bsub_rusage {
    return "";
}

sub execute {
    my $self = shift;
    $DB::single=1;

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

    my $tumor_model = $model->tumor_model;
    my $tumor_model_id = $tumor_model->genome_model_id;
    unless ($tumor_model_id) {
        $self->error_message("Failed to get a tumor_model_id for this build!");
        return;
    }
    
    my $normal_model = $model->normal_model;
    my $normal_model_id = $normal_model->genome_model_id;
    unless ($normal_model_id) {
        $self->error_message("Failed to get a normal_model_id for this build!");
        return;
    }

    my $data_directory = $self->build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        return;
    }
    
    my $workflow = Workflow::Command::SomaticPipeline->create(
        normal_model_id => $normal_model_id,
        tumor_model_id => $tumor_model_id,
        data_directory => $data_directory);

    unless ($workflow) {
        $self->error_message("Failed to create workflow!");
        return;
    }

    $workflow->execute();

    return 1;
}

1;
