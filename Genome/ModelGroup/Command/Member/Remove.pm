package Genome::ModelGroup::Command::Member::Remove;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Member::Remove {
    is => ['Genome::ModelGroup::Command::Member'],
    has => [
        model_ids   => { is => 'Text', doc => 'IDs of the model to remove from the model-group (comma delimited)' },
    ],
    doc => 'remove member models from a model-group',
};

sub help_synopsis {
    return <<"EOS"
genome model-group member add --model-group-id 21 --model-id 2813411994
genome model-group member add --model-group-id 21 --model-ids 2813411994,2813326667
EOS
}

sub help_brief {
    return "remove one or more models from a model-group";
}

sub help_detail {                           
    return <<EOS 
remove one or more models from a model-group
EOS
}

sub execute {
    my $self = shift;
    
    my $model_group = $self->model_group;
    
    my @model_ids = split(',', $self->model_ids);
    
    my @models_to_remove = Genome::Model->get(id => \@model_ids);
    my @existing_models = $self->model_group->models;
    
    for my $model_id (@model_ids) {
        if( my ($model) = grep ($_->id eq $model_id, @models_to_remove)) {
            if( grep ($_->id eq $model_id, @existing_models)) {
                $self->status_message('Removing model ' . $model->name . ' (' . $model_id . ') from the model-group...');
            } else {
                $self->warning_message('Model ' . $model->name . ' (' . $model_id . ') is not a member.');
                @models_to_remove = grep($_->id ne $model_id, @models_to_remove);
            }
        } else {
            $self->error_message('Could not find model for ID #' . $model_id);
        }
    }
    
    $model_group->unassign_models(@models_to_remove);
    
    return 1;
}

1;
