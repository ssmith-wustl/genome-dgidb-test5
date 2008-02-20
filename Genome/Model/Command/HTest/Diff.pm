package Genome::Model::Command::HTest::Diff;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::HTest::Diff {
    is => 'Genome::Model::Command::HTest',
};

sub sub_command_sort_position { 1 }

sub help_brief {
    "Managing diff sets";
}



1;

