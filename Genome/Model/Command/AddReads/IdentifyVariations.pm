
package Genome::Model::Command::AddReads::IdentifyVariations;

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

sub sub_command_sort_position { 4 }

sub help_brief {
    "identify genotype variations"
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command for the genotyper
specified in the model.
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

