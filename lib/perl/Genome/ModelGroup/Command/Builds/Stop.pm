package Genome::ModelGroup::Command::Builds::Stop;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Stop {
    is => ['Genome::ModelGroup::Command::Builds'],
    has_optional => [
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
        model_group_name => { is => 'String', doc => 'name of model-group'},
    ],
    doc => "stop latest build for each member if it is running or scheduled",
};

sub execute {
    my $self = shift;

    my $mg = $self->get_mg;

    my @models = $mg->models;
    for my $model (@models) {
        my $build = $model->latest_build;
        my $build_id = $build->id;
        my $model_name = $model->name;
        my $status = $build->status;
        if ($status =~ /Running|Scheduled/) {
            my $stop_build = Genome::Model::Build::Command::Stop->create(build_id => $build_id);
            $self->status_message("Stopping $build_id ($model_name)");
            unless($stop_build->execute()) {
                $self->error_message("Failed to stop build $build_id for model " . $model->name);
            }
        }
        else {
            $self->status_message("Skipping $build_id ($model_name)");
        }
    }
}
1;
