package Genome::Model::Command::AddReads::FindVariations;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::AddReads::FindVariations {    
    is => ['Genome::Model::EventWithRefSeq'],
};

sub sub_command_sort_position { 80 }

sub help_brief {
    "identify genotype variations"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads find-variations --model-id 5 --ref-seq-id all_sequences
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
    return 'indel_finder_name';
}

1;

