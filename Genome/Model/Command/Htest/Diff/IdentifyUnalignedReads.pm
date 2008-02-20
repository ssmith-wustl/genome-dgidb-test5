
package Genome::Model::Command::Htest::Diff::IdentifyUnalignedReads;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::Htest::Diff::IdentifyUnalignedReads {
    is => 'Command',
};

sub sub_command_sort_position { 2 }

sub help_brief {
    "identifies the list of reads which are not aligned and are candidates for realignment"
}

1;

