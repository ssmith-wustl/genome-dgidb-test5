
package Genome::Model::Command::AddReads;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model   =>  { is => 'String', 
                        doc => "Identifies the genome model to which we'll add the reads." },
    ]
);

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
genome-model add-reads --model ley_aml_patient1_solexa_cdna /SOME/PATH
EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to add a run,
or part of a run, to the specified model.

All of the sub-commands listed below will be executed on the model in succession.
EOS
}

#sub is_sub_command_delegator {
#    return 0;
#}

sub execute {
    my $self = shift;
    $self->status_message("Not implemented");
    return 1; 
}

1;

