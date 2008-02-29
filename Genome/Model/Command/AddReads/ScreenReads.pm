package Genome::Model::Command::AddReads::ScreenReads;

use strict;
use warnings;

use above "UR";
use Command; 

class Genome::Model::Command::AddReads::ScreenReads {
    is => ['Genome::Model::Command::DelegatesToSubcommand::WithRun'],
};

sub sub_command_sort_position { 15 }

sub help_brief {
    "Perform some kind of screening on reads, such as removing duplicate sequences";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads screen-reads --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command for the multi-read-fragment-strategy
specified in the model.
EOS
}

sub sub_command_delegator {
    my $self = shift;

    my $model = Genome::Model->get(id => $self->model_id);
    unless ($model) {
        $self->error_message("Can't retrieve a Genome Model with ID ".$self->model_id);
        return;
    }

    return $model->multi_read_fragment_strategy;
}
  
1;

