package Genome::Model::Command::AddReads::FilterVariations;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads::FilterVariations {    
    is => ['Genome::Model::EventWithRefSeq'],
};

sub sub_command_sort_position { 120 }

sub help_brief {
    "identify genotype variations"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads filter-variations --model-id 5 --ref-seq-id X 
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
    return 'filter_ruleset_name';
}

1;

