package Genome::Reference::Coverage::Region;

use strict;
use warnings;

use Genome;

class Genome::Reference::Coverage::Region {
    is => ['Genome::Reference::Coverage::RegionI'],
    has_optional => [
        name => { is => 'String', },
        chrom => { is => 'String', },
    ],
};


1;
