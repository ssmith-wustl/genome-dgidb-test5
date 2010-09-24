package Genome::ModelGroup::Command::Builds::Stop;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Stop {
    is => ['Genome::ModelGroup::Command::Builds'],
    doc => "stop latest build for each member if it is running or scheduled",
};

sub help_synopsis {
    return <<"EOS"
genome model-group builds stop...   
EOS
}

sub help_brief {
    "stop latest build for each member if it is running or scheduled"
}

sub help_detail {                           
    my $self = shift;
    return $self->help_brief;
}

sub execute {
    my $self = shift;

    my $mg = $self->get_mg;

    my @models = $mg->models;
    for my $model (@models) {
        my $build = $model->latest_build;
        next unless($build);
        my $build_id = $build->id;
        my $model_name = $model->name;
        my $status = $build->status;
        if ($status =~ /Running|Scheduled/) {
            my $stop_build = Genome::Model::Build::Command::Stop->create(build_id => $build_id);
            $self->status_message("Stopping $build_id ($model_name)");
            eval { $stop_build->execute() };
            if ($@) {
                UR::Context->commit;
            }
            else {
                $self->error_message("Failed to stop build $build_id for model " . $model->name);
            }
        }
        else {
            $self->status_message("Skipping $build_id ($model_name)");
        }
    }
    return 1;
}
1;
