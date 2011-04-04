#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 4;
}

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Samtools/';
my $test_working_dir = File::Temp::tempdir('DetectVariants2-SamtoolsXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $bam_input = $test_dir . '/alignments/102922275_merged_rmdup.bam';

# Updated to .v1 for addition of read depth field
# Updated to .v2 for changing the structure of the files in the output dir from 1) no more filtering snvs -- this was moved to the  filter module 2) output file names changed
# Updated to .v3 for correcting the output of insertions in the bed file
# Updated to .v4 for correcting the sort order of snvs.hq and indels.hq
my $expected_dir = $test_dir . '/expected.v4/';
ok(-d $expected_dir, "expected results directory exists");

my $refbuild_id = 101947881;

my $version = 'r613';

my $snv_parameters = my $indel_parameters = '';

my $command = Genome::Model::Tools::DetectVariants2::Samtools->create(
    reference_build_id => $refbuild_id,
    aligned_reads_input => $bam_input,
    version => $version,
    snv_params => $snv_parameters,
    indel_params => $indel_parameters,
    detect_snvs => 1,
    detect_indels => 1,
    output_directory => $test_working_dir,
);
ok($command, 'Created `gmt detect-variants2 samtools` command');
ok($command->execute, 'Executed `gmt detect-variants2 samtools` command');

my $diff_cmd = sprintf('diff -r -q %s %s', $test_working_dir, $expected_dir);

my $diff = `$diff_cmd`;
is($diff, '', 'No differences in output from expected result from running samtools for this version and parameters');
