package Genome::ModelGroup::Command::Builds::Remove;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Remove {
    is => ['Genome::ModelGroup::Command::Builds'],
    doc => "remove latest build for each member if it is abandoned",
};

sub help_synopsis {
    return <<"EOS"
genome model-group builds remove...   
EOS
}

sub help_brief {
    "remove latest build for each member if it is abandoned"
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
        my $model_name = $model->name;

        my $build = $model->latest_build;
        next unless($build);
        my $build_id = $build->id;
        my $status = $build->status;

        if ($status =~ /Abandoned/) {
            my $remove_build = Genome::Model::Build::Command::Remove->create(build_id => $build_id);
            $self->status_message("Removing $build_id ($model_name)");
            unless($remove_build->execute()) {
                $self->error_message("Failed to remove build $build_id for model " . $model->name);
            }
            UR::Context->commit;
        }
        else {
            $self->status_message("Skipping $build_id ($model_name)");
        }
    }
}
1;
