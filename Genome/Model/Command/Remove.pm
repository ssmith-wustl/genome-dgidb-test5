
package Genome::Model::Command::Remove;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::Command::Remove {
    is => 'Genome::Model::Command',
    has => [
            model_id => {
                         is => 'Integer',
                         doc => 'The model_id of the model you wish to remove',
                     }
        ]
};

sub sub_command_sort_position { 2 }

sub help_brief {
    "remove a genome-model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model remove FooBar
EOS
}

sub help_detail {
    return <<"EOS"
This command deletes the specified genome model.
EOS
}

sub execute {
    my $self = shift;
    my $model = Genome::Model->get($self->model_id);
    unless ($model) {
        $self->error_message('No model found for model_id '. $self->model_id);
        return;
    }
    unless ($model->delete) {
        $self->error_message('Failed to delete model '. $model->id);
        return;
    }
    return 1;
}

1;

