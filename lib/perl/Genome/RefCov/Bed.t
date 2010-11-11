#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More skip_all => 'The test BED file is way too big';
    #tests => 4;

BEGIN {	
    use_ok('Genome::RefCov::RegionI');
    use_ok('Genome::RefCov::Region');
    use_ok('Genome::RefCov::RegionFileI');
    use_ok('Genome::RefCov::Bed');
}
# TODO: find much more suitable BED file for test case
my $file = '/gscmnt/sata141/techd/twylie/CAPTURE_ROUND_ROBIN/SANGER.bed';
my $region_set = Genome::RefCov::Bed->create(file => $file);
my @chromosomes = $region_set->chromosomes;
is(scalar(@chromosomes),25,'got 25 chromosomes');
for my $chrom (@chromosomes) {
    my @regions = $region_set->chromosome_regions($chrom);
    is(scalar(@regions),1000);
}
exit;
