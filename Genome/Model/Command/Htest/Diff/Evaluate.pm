
package Genome::Model::Command::Htest::Diff::Evaluate;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::Htest::Diff::Evaluate {
    is => 'Command',
};

sub sub_command_sort_position { 5 }

sub help_brief {
    "perform one or more tests to compare alignments between the old and new consensus"
}

1;

