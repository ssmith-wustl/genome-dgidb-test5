package Genome::Sys::Command;

use Genome;
use strict;
use warnings;

class Genome::Sys::Command {
    is => 'Genome::Command::Base',
    is_abstract => 1,
    doc => 'work with OS integration',
};

1;
