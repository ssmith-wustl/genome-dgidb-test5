#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use File::Compare;
use Test::More;
use above 'Genome';

BEGIN {
    $ENV{NO_LSF} = 1;
}
my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 3;
}

my $tmpdir = File::Temp::tempdir('GMT-Pindel-RunPindel-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $test_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Pindel-RunPindel";
my $tumor_bam = $test_data."/true_positive_tumor_validation.bam";
my $normal_bam = $test_data."/true_positive_normal_validation.bam";
my $expected_directory = $test_data ."/expected_2";
my $expected_indels_hq = $expected_directory."/10/indels.hq";
my $actual_indels_hq = $tmpdir."/10/indels.hq";
my $refbuild_id = 101947881;

my $pindel = Genome::Model::Tools::Pindel::RunPindel->create(
                aligned_reads_input => $tumor_bam,
                control_aligned_reads_input => $normal_bam,
                reference_build_id => $refbuild_id,
                version => '0.5',
                output_directory => $tmpdir,
                chromosome => '10', );


ok($pindel, 'run-pindel command created');

my $result = $pindel->execute;
is($result, 1, 'Testing for execution.  Expecting 1.  Got: '.$result);

is(compare($actual_indels_hq,$expected_indels_hq),0,'Output for v0.5 is identical to expected output');
