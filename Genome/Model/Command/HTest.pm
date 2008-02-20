
package Genome::Model::Command::HTest;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::HTest {
    is => 'Command',
};

sub sub_command_sort_position { 20 }

sub help_brief {
    "Hypothesis testing";
}



1;

