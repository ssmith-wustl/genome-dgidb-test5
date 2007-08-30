
package Genome::Model::Command::AddReads::AssignRun;

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
EOS
}

sub help_detail {
    return <<"EOS"
EOS
}

sub Xexecute {
    my $self = shift;
    $self->status_message("Not implemented");
    return 1; 
}

1;

