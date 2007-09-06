package Genome::Model::Command::AddReads::UpdateGenotypeProbabilities;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => ['Genome::Model::Command::DelegatesToSubcommand'],
);

sub sub_command_sort_position { 3 }

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command for the genotyper
specified in the model.
EOS
}


sub sub_command_delegator {
    my $self = shift;

    my $model = Genome::Model->get(id => $self->model_id);
    unless ($model) {
        $self->error_message("Can't retrieve genome model with ID ".$self->model_id);
        return;
    }

    return $model->genotyper_name;
}



1;

