#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 3;

BEGIN {
    use_ok('Genome::RefCov::ROI::BedLite');
}
# TODO: find much more suitable BED file for test case
my $file = '/gscmnt/sata141/techd/twylie/CAPTURE_ROUND_ROBIN/SANGER.bed';
my $region_set = Genome::RefCov::ROI::BedLite->create(file => $file);
isa_ok($region_set,'Genome::RefCov::ROI::BedLite');
my $chromosomes = $region_set->chromosomes;
is(scalar(@{$chromosomes}),25,'got 25 chromosomes');
exit;
