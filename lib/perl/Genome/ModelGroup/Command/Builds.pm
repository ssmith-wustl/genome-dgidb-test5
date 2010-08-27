package Genome::ModelGroup::Command::Builds;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds {
    is => ['Genome::ModelGroup::Command'],
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

1;
