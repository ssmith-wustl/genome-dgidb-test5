
package Genome::Model::Command::Htest::Diff::IdentifyPossibleMisalignedReads;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::Htest::Diff::IdentifyPossibleMisalignedReads {
    is => 'Command',
};

sub sub_command_sort_position { 3 }

sub help_brief {
    "extract reads from maq map files where they are possible misalignments for realignment"
}

1;

