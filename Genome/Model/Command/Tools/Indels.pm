
package Genome::Model::Command::Tools::Indels;

use strict;
use warnings;

use UR;
use Genome::Model::Command::IterateOverRefSeq;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::IterateOverRefSeq',
);

sub help_brief {
    "examine coverage base-by-base"
}

sub help_synopsis {
    return <<"EOS"

Write a subclass of this.  

Give it a name which is an extension of this class name.

Implement an indel detection algorithm.

EOS
}

sub help_detail {
    return <<"EOS"

This module is an abstract base class for commands which resolve coverage.

Subclasses will implement different indel detection algorithms.  This module
should handle common coverage parameters, typically for handling the results. 

EOS
}


sub _print_result {
    my ($pos,$coverage) = @_;

    print "$pos:$coverage\n";
}

1;

