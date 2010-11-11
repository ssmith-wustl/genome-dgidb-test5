package Genome::RefCov::Region;

use strict;
use warnings;

use Genome;

class Genome::RefCov::Region {
    is => ['Genome::RefCov::RegionI'],
    has_optional => [
        name => { is => 'String', },
        chrom => { is => 'String', },
    ],
};


1;
