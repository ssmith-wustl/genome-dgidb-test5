
package Genome::Model::Command::IdentifyVariations;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model   =>  { is => 'String', 
                        doc => "identify genotype variations" }
    ]
);

sub help_brief {
    "identify genotype variations"
}

sub help_synopsis {
    return <<"EOS"
genome-model identify-variations --model MODEL
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

sub execute {
    my $self = shift;
    $self->status_message("Not implemented");
    return 1; 
}

1;

