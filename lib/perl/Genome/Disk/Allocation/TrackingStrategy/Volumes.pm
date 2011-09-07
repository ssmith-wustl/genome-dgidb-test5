package Genome::Disk::Allocation::TrackingStrategy::Volumes;

use strict;
use warnings;
use Genome;

class Genome::Disk::Allocation::TrackingStrategy::Volumes {
    is => 'Genome::Disk::Allocation::TrackingStrategy',,
    doc => 'Allocations are made on volumes, which are placed into groups ' .
        'via assignments. The caller must provide a request size in kb, ' .
        'which is used to track disk usage and prevent out-of-disk issues.',
};

1;

