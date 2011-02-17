package Genome::Disk::Group::Command;

use strict;
use warnings;

use Genome;

class Genome::Disk::Group::Command {
    is => 'Genome::Command::Base',
    is_abstract => 1,
    doc => 'work with disk groups',
};

1;

