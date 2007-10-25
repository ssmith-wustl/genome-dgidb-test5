package Genome::Model::Command::AddReads::UpdateGenotype;

use strict;
use warnings;

use above "Genome";
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => ['Genome::Model::Command::DelegatesToSubcommand::WithRefSeq'],
);

sub sub_command_sort_position { 6 }

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments update-genotype --model-id 5 
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

sub is_not_to_be_run_by_add_reads {
    return 1;
}


1;

