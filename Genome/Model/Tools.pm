
package Genome::Model::Tools;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Tools {
    is => 'Command',
};

sub help_brief {
    "misc tools which are used in conjunction with genome modeling"
}

sub sub_command_sort_position { 11 }

1;

