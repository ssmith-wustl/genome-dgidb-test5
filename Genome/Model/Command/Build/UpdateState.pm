package Genome::Model::Command::Build::UpdateState;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::UpdateState {
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
            force_flag => {
                           is => 'Number',
                           is_optional => 1,
                           doc => 'This flag when False will bail out from modifying any existing events.  When set to true(1) this flag will force all events to an abandoned state.  For any other behaviour, leave undefined.',
                         },
        ],
};

sub help_detail {
    "This module will update the state of a current running build";
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
    my $build_event = $build->build_event;
    unless ($build_event) {
        $self->error_message('No build event found for build '. $self->build_id);
        return;
    }
    unless ($build_event->update_build_state($self->force_flag)) {
        $self->status_message('Build '. $self->build_id .' is still running');
    }
    return 1;
}


1;

