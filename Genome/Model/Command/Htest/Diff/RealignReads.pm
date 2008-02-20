
package Genome::Model::Command::Htest::Diff::RealignReads;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::Htest::Diff::RealignReads {
    is => 'Command',
};

sub sub_command_sort_position { 4 }

sub help_brief {
    "hypothesize and test one or more sequence variations"
}

1;

