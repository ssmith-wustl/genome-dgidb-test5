package Genome::ModelGroup::Command::StartBuilds;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::StartBuilds {
    is => ['Command'],
    has_optional => [
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
        model_group_name => { is => 'String', doc => 'name of model-group'},
        max_active => { is => 'Integer', doc => 'how many models may be running or scheduled at any given time', default => 10000},
    ],
    doc => "start build for each member if latest build is not running or scheduled",
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
        last if ($active_count >= $self->max_active);

        my $model_id = $model->id;
        my $model_name = $model->name;
        my $status = $model->latest_build->status;
        if ($status !~ /Running|Scheduled/) {
            my $start_build = Genome::Model::Build::Command::Start->create(model_identifier => $model->id);
            $self->status_message("Starting " . $model->id . " ($model_name)");
            if ($start_build->execute()) {
                $active_count++;
            }
            else {
                $self->error_message("Failed to start build for model " . $model->name . " (" . $model->id . ").");
            }
        }
        else {
            $self->status_message("Skipping $model_id ($model_name)");
        }
        
    }
    return 1;
}
1;
