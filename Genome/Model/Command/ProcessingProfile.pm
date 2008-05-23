
package Genome::Model::Command::ProcessingProfile;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::ProcessingProfile {
    is => 'Genome::Model::Command',
};

sub help_brief {
    "creation of new processing profiles"
}

sub sub_command_sort_position { 13 }

1;

