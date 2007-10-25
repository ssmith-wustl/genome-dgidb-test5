package Genome::Model::Command::AddReads::IdentifyVariations;

use strict;
use warnings;

use above "Genome";
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::DelegatesToSubcommand::WithRefSeq',
);

sub sub_command_sort_position { 4 }

sub help_brief {
    "identify genotype variations"
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments identify-variations --model-id 5
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

    return $model->indel_finder_name;
}


1;

