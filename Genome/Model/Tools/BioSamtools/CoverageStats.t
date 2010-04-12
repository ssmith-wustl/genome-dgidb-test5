#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

use above 'Genome';

use_ok('Genome::Model::Tools::BioSamtools::CoverageStats');

my $tmp_dir = File::Temp::tempdir('BioSamtools-CoverageStats-'.$ENV{USER}.'-XXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites',CLEANUP => 1);

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-BioSamtools/RefCov';

my $bam_file = $data_dir .'/test.bam';
my $regions_file = $data_dir .'/test_regions.bed';

my $stats = Genome::Model::Tools::BioSamtools::CoverageStats->create(
    output_directory => $tmp_dir,
    bam_file => $bam_file,
    bed_file => $regions_file,
);
isa_ok($stats,'Genome::Model::Tools::BioSamtools::CoverageStats');
ok($stats->execute,'execute CoverageStats command '. $stats->command_name);

exit;
