package Genome::Task::Command;

use strict;
use warnings;

use Genome;

class Genome::Task::Command {
    is => 'Command',
    is_abstract => 1,
    doc => 'work with disk',
};


1;
