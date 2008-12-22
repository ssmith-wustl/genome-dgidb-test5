package Genome::Model::Command::Build::ScheduleStage;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ScheduleStage {
    is => ['Genome::Model::Command'],
    has => [
            stage_name => {
                           is => 'String',
                           doc => 'the name of the stage to schedule',
                       },
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
            force_flag => {
                           is => 'Number',
                           is_optional => 1,
                           doc => 'This flag when False will bail out from modifying any existing events.  When set to true(1) this flag will force all events to an abandoned state.  For any other behaviour, leave undefined.',
                       },
            auto_execute   => {
                               is => 'Boolean',
                               default_value => 1,
                               doc => 'The build will execute genome-model run-jobs before completing'
                           },
            hold_run_jobs  => {
                               is => 'Boolean',
                               default_value => 0,
                               doc => 'A flag to hold all lsf jobs that are scheduled in run-jobs'
                           },
        ],
};

sub help_detail {
    "This module will update the state of a current running build";
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    my $model = $self->model;
    unless ($self->build_id) {
        unless ($model->current_running_build_id) {
            my $new_build = Genome::Model::Command::Build->create(model_id => $model->id);
            unless ($new_build) {
                $self->error_message('Failed to launch new build');
                return;
            }
        }
        $self->build_id($model->current_running_build_id);
    }
    unless ($self->build_id eq $model->current_running_build_id) {
        $self->error_message('The build id '. $self->build_id
                             .' does not match the model current_running_build_id '.
                             $model->current_running_build_id);
        $self->SUPER::delete;
        return;
    }
    return $self;
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    my $build = $self->build;
    my @stages = $build->stages;
    my $index = undef;
    for (my $i = 0; $i < scalar(@stages); $i++) {
        if ($stages[$i] eq $self->stage_name) {
            $index = $i;
            last;
        }
    }
    unless (defined($index)) {
        $self->error_message('Failed to find stage '. $self->stage_name .".  Possible stage names include:\n". join("\n",@stages));
        return;
    }
    unless ($index == 0) {
        my $prior_stage_name = $stages[$index - 1];
        unless ($build->verify_successful_completion_for_stage($prior_stage_name,$self->force_flag)) {
            $self->error_message('Failed to verify completion of prior stage '. $prior_stage_name);
            return;
        }
    }
    my @existing_events = $build->events_for_stage($self->stage_name);
    if (scalar(@existing_events)) {
        $self->error_message('Found '. scalar(@existing_events) .' existing events for stage '.
                             $self->stage_name);
        return;
    }
    my @scheduled_objects = $build->_schedule_stage($self->stage_name);
    unless (@scheduled_objects) {
        $self->error_message('Failed to schedule stage for build('. $self->build_id ."). Objects not scheduled for classes:\n".
                             join("\n",$build->classes_for_stage($self->stage_name)));
        return;
    }
    if ($self->auto_execute) {
        my %run_jobs_params = (
                               model_id => $self->model_id,
                               building => 1,
                           );
        if ($self->hold_run_jobs) {
            $run_jobs_params{bsub_args} = ' -H ';
        }
        unless (Genome::Model::Command::RunJobs->execute(%run_jobs_params)) {
            $self->error_message('Failed to execute run-jobs for model '. $self->model_id);
            return;
        }
    }
    return 1;
}


1;

