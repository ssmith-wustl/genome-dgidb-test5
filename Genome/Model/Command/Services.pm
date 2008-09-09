
package Genome::Model::Command::Services;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::Services {
    is => 'Command',
};

sub help_brief {
    "services intended to be run out of cron or other task scheduler"
}

sub sub_command_sort_position { 11 }

1;

