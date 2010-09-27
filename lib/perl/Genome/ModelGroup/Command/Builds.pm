package Genome::ModelGroup::Command::Builds;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds {
    is => ['Genome::ModelGroup::Command'],
    has_optional => [
        item => { is => 'Text', shell_args_position => 1, doc => 'model group or name' },
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check' },
        model_group_name => { is => 'String', doc => 'name of model-group' },
    ],
    doc => "work with the builds of members of model-groups",
};

sub help_synopsis {
    return <<"EOS"
genome model-group builds ...   
EOS
}

sub help_brief {
    return "work with the builds of members of model-groups";
}

sub help_detail {                           
    return <<EOS 
Top level command to hold commands for working with the builds of members of model-groups.
EOS
}

sub get_mg {
    my $self = shift;
    
    my $mg;

    if (scalar(grep { $_ } ($self->item, $self->model_group_id, $self->model_group_name)) > 1) {
        $self->error_message("Please only specify one paramater (name or ID)");
        exit;
    }
    if($self->model_group_id || ($self->item && $self->item =~ /^-?\d+$/)) {
        my $id = $self->model_group_id || $self->item;
        $mg = Genome::ModelGroup->get($id);
    }
    if($self->model_group_name || ($self->item && !$mg)) {
        my $name = $self->model_group_name || $self->item;
        $mg = Genome::ModelGroup->get(name => $name);
    }
    unless($mg) {
        die $self->error_message("Unable to determine model group.");
    }
    $self->status_message("Found model group " . $mg->name . " (" . $mg->id . "):");

    return $mg;
}

sub count_active {
    my $self = shift;
    my $mg = shift;

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

1;
