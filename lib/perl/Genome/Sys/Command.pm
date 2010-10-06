package Genome::Sys::Command;
use strict;
use warnings;
use Genome;

class Genome::Sys::Command {
    is => 'UR::Value',
    doc => 'A real command executable from the command line',
    has => {
        name => {
            calculate_from => ['id'],
            calculate => q(
                return $id;
            )
        }
    }
};

1;

