package Genome::ModelGroup::Command::Builds::Start;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Start {
    is => ['Genome::ModelGroup::Command::Builds'],
    has_optional => [
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
        model_group_name => { is => 'String', doc => 'name of model-group'},
        max_active => { is => 'Integer', doc => 'how many models may be running or scheduled at any given time', default => 10000},
    ],
    doc => "start build for each member if latest build is not running or scheduled",
};

sub help_synopsis {
    return <<"EOS"
genome model-group builds start...   
EOS
}

sub help_brief {
    "restart build for each member if latest build is failed or scheduled"
}

sub help_detail {                           
    my $self = shift;
    return $self->help_brief;
}

sub execute {
    my $self = shift;
    my %status;

    my $mg = $self->get_mg;

    my $active_count = $self->count_active;

    for my $model ($mg->models) {
        my $model_name = $model->name;
        my $model_id = $model->id;

        last if ($active_count >= $self->max_active);

        my $build = $model->latest_build;
        my $status;
        if ($build) {
            $status = $build->status;
        }
        else {
            $status = '';
        }
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
