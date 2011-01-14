#!/gsc/bin/perl

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
# TODO: find much more suitable BED file for test case
my $file = '/gscmnt/sata141/techd/twylie/CAPTURE_ROUND_ROBIN/SANGER.bed';
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
