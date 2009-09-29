package Genome::Model::Command::Build::VerifySuccessfulCompletion;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::VerifySuccessfulCompletion {
    is => ['Genome::Model::Event'],
    has_optional => [
        force_abandon => {
            is => 'Boolean',
            default_value => 0,
            doc => 'A flag to force abandon of failed events(default=0)',
        },
    ],
    doc => 'verify that a given build has completed successfully',
};

sub sub_command_sort_position { 6 }

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
    unless ($build) {
        $self->error_message('No build found with id '. $self->build_id);
        return;
    }
    my $build_event = $build->build_event;
    unless ($build_event) {
        $self->error_message('Build event not found for model '.
                             $self->model_id .' and build '. $self->build_id);
        return;
    }
    if ($build_event->verify_successful_completion($self->force_abandon)) {
        my $disk_allocation = $build->disk_allocation;
        if ($disk_allocation) {
            my $reallocate = Genome::Disk::Allocation::Command::Reallocate->execute( allocator_id => $disk_allocation->allocator_id);
            unless ($reallocate) {
                $self->warning_message('Failed to reallocate disk space.');
            }
        }
        #$build_event->event_status('Succeeded');
        #$build_event->date_completed(UR::Time->now);
        $self->event_status('Succeeded');
        $self->date_completed(UR::Time->now);
        #$model->current_running_build_id(undef);
        #$model->last_complete_build_id($build_event->build_id);
    } else {
        #$build_event->event_status('Failed');
        #$build_event->date_completed(UR::Time->now);
        $self->event_status('Failed');
        $self->date_completed(UR::Time->now);
    }
    return 1;
}


1;

