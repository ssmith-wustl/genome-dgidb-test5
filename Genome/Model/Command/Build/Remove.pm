package Genome::Model::Command::Build::Remove;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Remove {
    is => ['Genome::Model::Command'],
    has => [
            build_id => {
                         is => 'Number',
                         doc => 'The id of the build in which to update status',
                         is_optional => 1,
                     },
            build   => {
                        is => 'Genome::Model::Build',
                        id_by => 'build_id',
                        is_optional => 1,
                    },
    ],
    doc => 'delete a build and all of its data from the system'
};

sub sub_command_sort_position { 7 }

sub help_detail {
    "This command will remove the build and all events that make up the build";
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($self->build_id) {
        $self->build_id($model->current_running_build_id);
    }
    my $build = $self->build;
    unless ($build) {
        $self->error_message('Build not found for model id '. $self->model_id .' and build id '. $self->build_id);
        return;
    }

    # cribbed from genome model build abandon - kills running jobs
    # if any events are running
    my @events = $build->build_events;
    foreach my $event (@events) {
        if($event->event_status =~ /Running/)
        {
            my $rv = eval { $build->abandon; };
            unless ($rv and not $@) {
                $self->error_message(
                    'Failed to abandon build '
                    . $self->build_id 
                    . ($@ ? " ERRORS: $@" : "")
                    );
                return;
            }
            last;
        }
    }
    unless ($build->delete) {
        $self->error_message('Failed to remove build '. $self->build_id);
        return;
    }
    return 1;
}


1;

