#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 6;

BEGIN {
    use_ok('Genome::RefCov::ROI::RegionI');
    use_ok('Genome::RefCov::ROI::Region');
    use_ok('Genome::RefCov::ROI::FileI');
    use_ok('Genome::RefCov::ROI::Bed');
}
# TODO: Subset bed file into one or two entries per chr
my $file = '/gsc/var/cache/testsuite/data/Genome-RefCov-ROI-Bed/SANGER.bed';
my $region_set = Genome::RefCov::ROI::Bed->create(
    file => $file,
);
my @chromosomes = $region_set->chromosomes;
is(scalar(@chromosomes),25,'got 25 chromosomes');
while (my $region = $region_set->next_region) {
    isa_ok($region,'HASH','got region as hash');
    last;
}

exit;
