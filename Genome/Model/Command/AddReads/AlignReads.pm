package Genome::Model::Command::AddReads::AlignReads;

use strict;
use warnings;

use above "UR";
use Command; 

class Genome::Model::Command::AddReads::AlignReads {
    is => ['Genome::Model::Command::DelegatesToSubcommand::WithRun'],
};

sub sub_command_sort_position { 20 }

sub help_brief {
    "Run the aligner tool on the reads being added to the model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command for the aligner
specified in the model.
EOS
}

sub command_subclassing_model_property {
    return 'read_aligner_name';
}

sub should_bsub { 1;}
  
1;

