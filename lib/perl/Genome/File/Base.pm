package Genome::File::Base;

use strict;
use warnings;
use Genome;

class Genome::File::Base {
    is => 'UR::Value',
};

sub path {
    return shift->id
}

1;

