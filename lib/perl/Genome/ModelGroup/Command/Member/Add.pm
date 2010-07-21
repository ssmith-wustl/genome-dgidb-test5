package Genome::ModelGroup::Command::Member::Add;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Member::Add {
    is => ['Genome::ModelGroup::Command::Member'],
    has => [
        model_ids   => { is => 'Text', doc => 'IDs of the models to add to the model-group (comma delimited)' },
    ],
    doc => 'add member models to a model-group',
};

sub help_synopsis {
    return <<"EOS"
genome model-group member add --model-group-id 21 --model-id 2813411994
genome model-group member add --model-group-id 21 --model-ids 2813411994,2813326667
EOS
}

sub help_brief {
    return "add one or more models to a model-group";
}

sub help_detail {                           
    return <<EOS 
add one or more models to a model-group
EOS
}

sub execute {
    my $self = shift;
    
    my $model_group = $self->model_group;
    
    my @model_ids = split(/,\s*/, $self->model_ids); 
    
    my @new_models = Genome::Model->get(id => \@model_ids);
    my @existing_models = $self->model_group->models;
    
    for my $model_id (@model_ids) {
        if( my ($model) = grep ($_->id eq $model_id, @new_models)) {
            if( grep ($_->id eq $model_id, @existing_models)) {
                $self->warning_message('Model ' . $model->name . ' (' . $model_id . ') is already a member.');
                @new_models = grep($_->id ne $model_id, @new_models);
            } else {
                $self->status_message('Adding model ' . $model->name . ' (' . $model_id . ')...');
            }
        } else {
            $self->error_message('Could not find model for ID #' . $model_id);
        }
    }
    
    $model_group->assign_models(@new_models);
    
    return 1; #Things might not have gone perfectly, but nothing crazy happened
}

1;
