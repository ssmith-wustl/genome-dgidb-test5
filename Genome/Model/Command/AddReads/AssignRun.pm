
package Genome::Model::Command::AddReads::AssignRun;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads::AssignRun {
    is => ['Genome::Model::Command::DelegatesToSubcommand::WithRun'],
};

sub sub_command_sort_position { 1 }

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads assign-run --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command according to 
the model's sequencing platform.
EOS
}

sub sub_command_delegator {
    my $self = shift;

    my $run = Genome::RunChunk->get(id => $self->run_id);
    return unless $run;

    return $run->sequencing_platform;
}
    

1;

