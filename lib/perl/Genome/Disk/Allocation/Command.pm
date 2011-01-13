package Genome::Disk::Allocation::Command;

use strict;
use warnings;

use Genome;

class Genome::Disk::Allocation::Command {
    is => 'Command',
    is_abstract => 1,
    doc => 'work with disk allocations',
};
