
package Genome::Model::Command::AddReads::AssignRun;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => ['Genome::Model::Command::DelegatesToSubcommand'],
);

sub sub_command_sort_position { 1 }

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
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

