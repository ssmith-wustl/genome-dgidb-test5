package Genome::Model::Command::Build::VerifySuccessfulCompletion;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::VerifySuccessfulCompletion {
    is => ['Genome::Model::Event'],
};

sub help_detail {
    "This module will update the status of a current running build";
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($self->build_id) {
        unless ($model->current_running_build_id) {
            $self->error_message('Current running build id not found for model '. $model->name .'('. $model->id .')');
            return;
        }
        $self->build_id($model->current_running_build_id);
    }
    my $build = $self->build;
    my $builder = $build->builder;
    unless ($builder) {
        $self->error_message('Builder event not found for model '.
                             $self->model_id .' and build '. $self->build_id);
        return;
    }
    if ($builder->verify_successful_completion) {
        $builder->event_status('Succeeded');
        $builder->date_completed(UR::Time->now);
        $self->event_status('Succeeded');
        $self->date_completed(UR::Time->now);
        $model->current_running_build_id(undef);
        $model->last_complete_build_id($builder->build_id);
    } else {
        $builder->event_status('Failed');
        $builder->date_completed(UR::Time->now);
        $self->event_status('Failed');
        $self->date_completed(UR::Time->now);
    }
    return 1;
}

sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;

