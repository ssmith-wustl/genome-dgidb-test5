package Genome::Model::Command::Build::VerifySuccesfulCompletion;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::VerifySuccesfulCompletion {
    is => ['Genome::Model::Event'],
    has => [
            build_id => {
                         is => 'Number',
                         doc => 'The id of the build in which to update status',
                         is_optional => 1,
                     },
            build   => {
                        is => 'Genome::Model::Command::Build',
                        id_by => 'build_id',
                        is_optional => 1,
                    },
        ],
};

sub help_detail {
    "This module will update the status of a current running build";
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($self->build_id) {
        $self->build_id($model->current_running_build_id);
    }
    my $build = $self->build;
    if ($build->verify_succesful_completion) {
        $build->event_status('Succeeded');
        $build->date_completed(UR::Time->now);
        $self->event_status('Succeeded');
        $self->date_completed(UR::Time->now);
        $model->current_running_build_id(undef);
        $model->last_complete_build_id($build->build_id);
    } else {
        $build->event_status('Failed');
        $build->date_completed(UR::Time->now);
        $self->event_status('Failed');
        $self->date_completed(UR::Time->now);
    }
    return 1;
}

sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;

