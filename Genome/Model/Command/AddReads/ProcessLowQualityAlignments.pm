package Genome::Model::Command::AddReads::ProcessLowQualityAlignments;

use strict;
use warnings;

use above "UR";
use Command; 

class Genome::Model::Command::AddReads::ProcessLowQualityAlignments {
    is => ['Genome::Model::EventWithReadSet'],
};

sub sub_command_sort_position { 25 }

sub help_brief {
    "Using the unaligned read info from the align-reads step, create a new fastq with just those reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads process-low-quality-alignments --model-id 5 --run-id 10
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
  
1;

