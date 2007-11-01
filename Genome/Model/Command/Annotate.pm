
package Genome::Model::Command::Annotate;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::Annotate {
    is => 'Genome::Model::Event',
};

sub help_brief {
    "add information about a genome model to the database"
}

sub sub_command_sort_position { 10 }

1;

