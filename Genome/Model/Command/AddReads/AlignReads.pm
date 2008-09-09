package Genome::Model::Command::AddReads::AlignReads;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::AddReads::AlignReads {
    is => ['Genome::Model::EventWithReadSet'],
    is_abstract => 1,
    has_abstract => [
        aligner_output_file_paths => { 
            doc => "the paths to the filed which captured the aligners standard output and error and/or log"
        },
        alignment_file_paths => {
            doc => "the paths to to the alignment files"
        },
    ]
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

