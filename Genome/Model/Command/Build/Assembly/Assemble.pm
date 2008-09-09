package Genome::Model::Command::Build::Assembly::Assemble;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Command::Build::Assembly::Assemble {
    is_abstract => 1,
    is => ['Genome::Model::Event'],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "assemble the reads in a project"
}

sub help_synopsis {
    return <<"EOS"
    genome-model build assembly assemble --model-id 5 --read-set-id 10
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by build assembly.

It delegates to the appropriate sub-command according to
the assembler.
EOS
}

sub command_subclassing_model_property {
    return 'assembler';
}

sub should_bsub { 1;}

1;

