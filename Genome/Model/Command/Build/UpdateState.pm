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
                        is => 'Genome::Model::Command::Build',
                        id_by => 'build_id',
                        is_optional => 1,
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
    unless ($build->update_build_state) {
        $self->status_message('Build '. $self->build_id .' is still running');
    }
    return 1;
}


1;

