
package Genome::Model::Command::ProcessingProfile::ShortRead;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::ProcessingProfile::ShortRead {
    is => 'Genome::Model::Command',
};

sub help_brief {
    "creation of new processing profiles for short reads"
}

sub sub_command_sort_position { 1 }

1;

