package Genome::Model::Command::Build::Assembly::AssignReadSetToModel;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Command::Build::Assembly::AssignReadSetToModel {
    is_abstract => 1,
    is => ['Genome::Model::EventWithReadSet'],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model build assembly add-read-set-to-model --model-id 5 --read-set-id 10
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "build assembly".

It delegates to the appropriate sub-command according to
the model's sequencing platform.
EOS
}

sub command_subclassing_model_property {
    return 'sequencing_platform';
}

sub should_bsub { 1;}

1;

