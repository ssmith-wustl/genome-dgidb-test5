package Genome::Model::Command::Build::ForceStage;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ForceStage {
    is => ['Genome::Model::Event'],
    has => [
            stage_name => {
                           is => 'String',
                           doc => 'The name of the stage you wish to force execution',
                       },
            build_id => {
                         is => 'Number',
                         doc => 'The id of the build in which to force stage execution',
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
    "This module will allow the user to force execution of a stage regardless of existing dependencies";
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($self->build_id) {
        $self->build_id($model->current_running_build_id);
    }
    return $self->build->_force_stage($self->stage_name);
}


1;

