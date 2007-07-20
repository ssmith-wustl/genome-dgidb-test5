
package Genome::Model::Command::Write;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "export data into a given file format"
}

sub help_synopsis {
    return <<"EOS"

Write a subclass of this.  

Give it a name which is an extension of this class name.

Implement a new writing out for some part  of a genome model.

EOS
}

sub help_detail {
    return <<"EOS"

This module is an abstract base class for commands which resolve coverage.

Subclasses will implement different per-base consensus calling algorithms.  This module
should handle common coverage parameters, typically for handling the results. 

EOS
}


sub _print_result {
    my ($pos,$coverage) = @_;

    print "$pos:$coverage\n";
}

1;

