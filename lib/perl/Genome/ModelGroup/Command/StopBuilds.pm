package Genome::ModelGroup::Command::StopBuilds;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::StopBuilds {
    is => ['Command'],
    has_optional => [
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
        model_group_name => { is => 'String', doc => 'name of model-group'},
    ],
    doc => "stop latest build for each member if it is running or scheduled",
};

sub get_mg {
    my $self = shift;
    
    my $mg;

    if($self->model_group_id && $self->model_group_name) {
        $self->error_message("Please specify either ID or name, not both.");
        die $self->error_message;
    }
    elsif($self->model_group_id) {
        $mg = Genome::ModelGroup->get($self->model_group_id);
    }
    elsif($self->model_group_name) {
        $mg = Genome::ModelGroup->get(name => $self->model_group_name);
    }
    else {
        $self->error_message("Please specify either an ID xor a name.");
        die $self->error_message;
    }

    return $mg;
}

sub execute {
    my $self = shift;

    my $mg = $self->get_mg;

    my @models = $mg->models;
    for my $model (@models) {
        my $build = $model->latest_build;
        my $build_id = $build->id;
        my $status = $build->status;
        if ($status =~ /Running|Scheduled/) {
            my $stop_build = Genome::Model::Build::Command::Stop->create(build_id => $build_id);
            $self->status_message("Stopping $build_id");
            #unless($stop_build->execute()) {
            #    $self->error_message("Failed to stop build $build_id for model " . $model->name);
            #}
        }
    }
}
1;
