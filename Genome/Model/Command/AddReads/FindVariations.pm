package Genome::Model::Command::AddReads::FindVariations;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads::FindVariations {    
    is => 'Genome::Model::Command::DelegatesToSubcommand::WithRefSeq',
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

sub sub_command_delegator {
    my($class,%params) = @_;

    my $model = Genome::Model->get(id => $params{'model_id'});
    unless ($model) {
        $class->error_message("Can't retrieve genome model with ID ".$params{'model_id'});
        return;
    }

    return $model->indel_finder_name;
}

sub is_not_to_be_run_by_add_reads {
    return 1;
}

1;

