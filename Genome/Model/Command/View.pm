
package Genome::Model::Command::View;

use strict;
use warnings;

use above "Genome";
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "view parts of a genome model with a given tool"
}

sub help_synopsis {
    return <<"EOS"

Write a subclass of this.  

Give it a name which is an extension of this class name.

Implement a new viewer for some part  of a genome model.

EOS
}

sub help_detail {
    return <<"EOS"

This module is an abstract base class for commands which resolve coverage.

Subclasses will implement different per-base consensus calling algorithms.  This module
should handle common coverage parameters, typically for handling the results. 

EOS
}

1;

sub sub_command_sort_position { 7 }
