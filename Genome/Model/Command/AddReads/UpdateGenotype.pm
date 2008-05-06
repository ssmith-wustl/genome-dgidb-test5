package Genome::Model::Command::AddReads::UpdateGenotype;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads::UpdateGenotype {
    is => ['Genome::Model::EventWithRefSeq'],
};

sub sub_command_sort_position { 70 }

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command for the genotyper
specified in the model.
EOS
}

sub command_subclassing_model_property {
    return 'genotyper_name';
}

sub is_not_to_be_run_by_add_reads {
    return 1;
}


1;

