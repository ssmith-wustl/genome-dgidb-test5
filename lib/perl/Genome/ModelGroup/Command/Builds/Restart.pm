package Genome::ModelGroup::Command::Builds::Restart;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Restart {
    is => ['Command'],
    has_optional => [
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
        model_group_name => { is => 'String', doc => 'name of model-group'},
        max_active => { is => 'Integer', doc => 'how many models may be running or scheduled at any given time', default => 10000},
    ],
    doc => "restart build for each member if latest build is failed or scheduled",
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

sub count_active {
    my $self = shift;

    my $mg = $self->get_mg;
    
    my $active_count = 0;
    for my $model ($mg->models) {
        my $build = $model->latest_build;
        if ($build) {
            my $status = $build->status;
            $active_count++ if($status eq 'Running' || $status eq 'Scheduled');
        }
    }

    return $active_count;
}

sub execute {
    my $self = shift;
    my %status;

    my $mg = $self->get_mg;

    my $active_count = $self->count_active;

    for my $model ($mg->models) {
        my $model_name = $model->name;

        last if ($active_count >= $self->max_active);

        my $build = $model->latest_build;
        next unless($build);
        my $build_id = $build->id;
        my $status = $build->status;
        if ($status =~ /Scheduled|Failed/) {
            my $build_id = $build->id;
            my $restart_build = Genome::Model::Build::Command::Restart->create(build_id => $build_id);
            $self->status_message("Restarting $build_id ($model_name)");
            if ($restart_build->execute()) {
                $active_count++;
            }
            else {
                $self->error_message("Failed to restart build ($build_id) for model " . $model->name . " (" . $model->id . ").");
            }
        }
        else {
            $self->status_message("Skipping $build_id ($model_name)");
        }
    }
    return 1;
}
1;
