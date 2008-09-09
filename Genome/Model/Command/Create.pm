
package Genome::Model::Command::Create;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Create {
    is => 'Genome::Model::Command',
};

sub help_brief {
    "creation of new models, processing profiles, etc" 
}

sub sub_command_sort_position { 1 }

1;

