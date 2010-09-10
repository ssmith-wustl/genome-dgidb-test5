package Genome::ModelGroup::Command::Builds::Restart;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Restart {
    is => ['Genome::ModelGroup::Command::Builds'],
    has_optional => [
        max_active => { is => 'Integer', doc => 'how many models may be running or scheduled at any given time', default => 10000},
    ],
    doc => "restart build for each member if latest build is failed or scheduled",
};

sub help_synopsis {
    return <<"EOS"
genome model-group builds restart...   
EOS
}

sub help_brief {
    "restart build for each member if latest build is failed or scheduled or running"
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

        last if ($active_count >= $self->max_active);

        my $build = $model->latest_build;
        next unless($build);
        my $build_id = $build->id;
        my $status = $build->status;
        if ($status =~ /Scheduled|Failed|Running/) {
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
