
package Genome::Model::Command::CalculateGenotype;

use strict;
use warnings;

use UR;
use Genome::Model::Command::IterateOverRefSeq;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::IterateOverRefSeq',
);

sub help_brief {
    "generate base-by-base consensus genotype"
}

sub help_synopsis {
    return <<"EOS"

???

Launch a genotyping algorithm.

EOS
}

sub help_detail {
    return <<"EOS"

This module is an abstract base class for commands which resolve consensus's.

Subclasses will implement different per-base consensus calling algorithms.  This module
should handle common consensus parameters, typically for handling the results. 

EOS
}


sub _print_result {
    my ($pos,$coverage) = @_;

    print "$pos\t$coverage\n";
}

1;

