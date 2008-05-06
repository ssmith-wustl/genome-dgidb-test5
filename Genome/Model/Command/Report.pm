
package Genome::Model::Command::Report;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::Report {
    is => 'Genome::Model::Command',
};

sub help_brief {
    "generate reports for a given model"
}

sub sub_command_sort_position { 12 }

1;

