
package Genome::Model::Command::AlignReads;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model   =>  { is => 'String', 
                        doc => "Identifies the genome model on which we'll align the reads." },
    ]
);

sub help_brief {
    "align reads from added runs against a reference sequence"
}

sub help_synopsis {
    return <<"EOS"
genome-model align-reads --model MODEL 
EOS
}

sub help_detail {
    return <<"EOS"
This command will align reads against either the reference prescribed when the model was created
or a reference specified on the command line at runtime.
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

