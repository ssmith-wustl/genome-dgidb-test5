package Genome::ModelGroup::Command::Builds::Abandon;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Abandon {
    is => ['Genome::ModelGroup::Command::Builds'],
    doc => "abandon latest build for each member if it is failed",
};

sub help_synopsis {
    return <<"EOS"
genome model-group builds abandon...   
EOS
}

sub help_brief {
    "abandon latest build for each member if it is failed"
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

        if ($status =~ /Failed/) {
            my $abandon_build = Genome::Model::Build::Command::Abandon->create(build_id => $build_id);
            $self->status_message("Abandoning $build_id ($model_name)");
            eval {
                if($abandon_build->execute()) {
                    UR::Context->commit;
                }
                else {
                    $self->error_message("Failed to abandon build $build_id for model " . $model->name);
                }
            };
        }
        else {
            $self->status_message("Skipping $build_id ($model_name)");
        }
    }
    return 1;
}
1;
