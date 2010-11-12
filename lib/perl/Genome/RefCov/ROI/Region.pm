package Genome::RefCov::ROI::Region;

use strict;
use warnings;

use Genome;

class Genome::RefCov::ROI::Region {
    is => ['Genome::RefCov::ROI::RegionI'],
    has_optional => [
        name => { is => 'String', },
        chrom => { is => 'String', },
    ],
};


1;
