
package Genome::Model::Command::AddReads::UpdateGenotypeProbabilities;

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

sub sub_command_sort_position { 3 }

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

It delegates to the appropriate sub-command for the genotyper
specified in the model.
EOS
}

sub execute {
    my $self = shift;
    $self->status_message("Not implemented: " . $self->command_name);
    return 1; 
}

1;

