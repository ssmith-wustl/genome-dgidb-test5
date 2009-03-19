#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

use above 'Genome';

BEGIN {
        use_ok('Genome::Disk::Allocation');
};
my @allocations = Genome::Disk::Allocation->get();
ok(scalar(@allocations),'got allocations');


exit;
