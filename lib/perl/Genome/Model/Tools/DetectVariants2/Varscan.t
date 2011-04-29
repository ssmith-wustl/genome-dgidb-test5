#!/gsc/bin/perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';
use Genome::SoftwareResult;
use Test::More;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 5;
}

use_ok('Genome::Model::Tools::DetectVariants2::Varscan');

# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Varscan/';
my $test_base_dir = File::Temp::tempdir('DetectVariants2-VarscanXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $test_working_dir = "$test_base_dir/output";

my $bam_input = $test_dir . '/alignments/102922275_merged_rmdup.bam';

# Updated to .v5 due to additional column in Varscan
# Updated to .v6 due to the addition of quality and natural sort order to bed file output 
# Updated to .v7 due to the addition of read depth
# Updated to .v8 due to directory structure changes
my $expected_dir = $test_dir . '/expected.v10/';
ok(-d $expected_dir, "expected results directory exists");


my $refbuild_id = 101947881;

my $version = ''; #Currently only one version of varscan

my $command = Genome::Model::Tools::DetectVariants2::Varscan->create(
    reference_build_id => $refbuild_id,
    aligned_reads_input => $bam_input,
    version => $version,
    params => "",
    output_directory => $test_working_dir,
);
ok($command, 'Created `gmt detect-variants varscan` command');
ok($command->execute, 'Executed `gmt detect-variants varscan` command');

my $diff_cmd = sprintf('diff -r -q %s %s', $test_working_dir, $expected_dir);

my $diff = `$diff_cmd`;
is($diff, '', 'No differences in output from expected result from running varscan for this version and parameters');
