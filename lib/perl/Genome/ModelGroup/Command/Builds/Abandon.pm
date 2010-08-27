package Genome::ModelGroup::Command::Builds::Abandon;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Abandon {
    is => ['Genome::ModelGroup::Command::Builds'],
    has_optional => [
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
        model_group_name => { is => 'String', doc => 'name of model-group'},
    ],
    doc => "abandon latest build for each member if it is failed",
};

sub execute {
    my $self = shift;

    my $mg = $self->get_mg;

    my @models = $mg->models;
    for my $model (@models) {
        my $model_name = $model->name;

        my $build = $model->latest_build;
        next unless($build);
        my $build_id = $build->id;
        my $status = $build->status;

        if ($status =~ /Failed/) {
            my $abandon_build = Genome::Model::Build::Command::Abandon->create(build_id => $build_id);
            $self->status_message("Abandoning $build_id ($model_name)");
            unless($abandon_build->execute()) {
                $self->error_message("Failed to abandon build $build_id for model " . $model->name);
            }
        }
        else {
            $self->status_message("Skipping $build_id ($model_name)");
        }
    }
}
1;
