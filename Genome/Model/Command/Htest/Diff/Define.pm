
package Genome::Model::Command::Htest::Diff::Define;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::Htest::Diff::Define {
    is => 'Command',
};

sub sub_command_sort_position { 1 }

sub help_brief {
    "define a new hypothetical consensus from an old by supplying a list of indels"
}

1;

