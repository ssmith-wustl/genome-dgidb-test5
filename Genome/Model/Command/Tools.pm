
package Genome::Model::Command::Tools;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::Tools {
    is => 'Command',
};

sub help_brief {
    "misc tools which are used in conjunction with genome modeling"
}

sub sub_command_sort_position { 11 }

1;

