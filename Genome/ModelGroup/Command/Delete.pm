package Genome::ModelGroup::Command::Delete;

#REVIEW fdu 11/20/2009
#1. Remove 'use Data::Dumper'
#2. Need add codes to check which models are using the
#processing-profile to be deleted and print out the list as warning

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Delete {
    is => 'Command',
    has => [
        'model_group'    => { is => 'Genome::ModelGroup', id_by => 'model_group_id'},
        'model_group_id' => { is => 'Integer', doc => 'id of the model-group to delete'},
    ]
};

sub help_synopsis {
    return <<"EOS"
genome model-group delete --model-group-id 2
EOS
}

sub help_brief {
    return "delete a model-group";
}

sub help_detail {                           
    return <<EOS 
delete a model-group
EOS
}

sub execute {
    my $self = shift;

    unless($self->model_group) {
        $self->error_message('No model-group found for id: ' . $self->model_group_id);
        return;
    }
    
    my $name = $self->model_group->name;
    
    unless($self->model_group->delete) {
        $self->error_message('Error deleting model-group #' . $self->model_group_id . ': ' . $name);
        return;
    }
    
    $self->status_message('Deleting model-group #' . $self->model_group_id . ': ' . $name);

    return 1;
}

1;
