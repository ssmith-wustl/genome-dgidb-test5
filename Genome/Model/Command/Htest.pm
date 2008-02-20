
package Genome::Model::Command::Htest;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::Htest {
    is => 'Command',
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "hypothesis testing"
}

1;

