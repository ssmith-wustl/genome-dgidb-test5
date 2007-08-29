
package Genome::Model::Command::AddReads;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model   =>  { is => 'Genome::Model', id_by => 'model_name',
                        doc => "Identifies the genome model to which we'll add the reads." },
    ]
);

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
genome-model add-reads /SOME/PATH
EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to add a run,
or part of a run, to the specified model.
EOS
}

#sub is_sub_command_delegator {
#    return 0;
#}

#sub execute {
#    my $self = shift;
#    $self->status_message("Not implemented");
#    return 1; 
#}

1;

