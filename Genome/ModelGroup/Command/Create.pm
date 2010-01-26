package Genome::ModelGroup::Command::Create;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Create {
    is => 'Command',
    has => [
        name => {
            is => 'Text',
            len => 255, 
            doc => 'A name for the model-group.', 
        },
    ],
};

sub help_brief {
    return "create a new model-group";
}

sub help_detail {
    return "create a new model-group";
}

sub help_synopsis {
    return 'genome model-group create --name "Example Group Name"';
}

sub execute {
    my $self = shift;
    
    unless($self->name) {
        $self->error_message('No name specified.');
        return;
    }
    
    my $model_group = Genome::ModelGroup->create(
        name => $self->name
    );
    
    unless($model_group) {
        $self->error_message('Failed to create model group');
        return;
    }
    
    $self->status_message('Created model group:');
    $self->status_message('ID: ' . $model_group->id . ', NAME: ' . $model_group->name);
    
    return 1;
}

1;
