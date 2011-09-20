package Genome::Disk::Allocation::TrackingStrategy;

use strict;
use warnings;
use Genome;

class Genome::Disk::Allocation::TrackingStrategy {
    is_abstract => 1,
    doc => 'Interface for allocation tracking strategies',
};

sub allocate {
    die "Tracking strategy does not implement allocate method!";
}

sub reallocate {
    die "Tracking strategy does not implement reallocate method!";
}

sub deallocate {
    die "Tracking strategy does not implement deallocate method!";
}

1;

