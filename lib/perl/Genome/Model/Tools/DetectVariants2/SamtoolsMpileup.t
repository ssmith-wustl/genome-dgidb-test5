#!/gsc/bin/perl


use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';
use Test::More;
use Genome::SoftwareResult;



my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 4;
}



use_ok('Genome::Model::Tools::DetectVariants2::Samtools');



# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};



my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Samtools/';
my $test_base_dir = #File::Temp::tempdir('DetectVariants2-SamtoolsXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $test_working_dir_mpileup = "$test_base_dir/output1";
my $bam_input = $test_dir . '/alignments/102922275_merged_rmdup.bam';

# Updated to .v1 for addition of read depth field
# Updated to .v2 for changing the structure of the files in the output dir from 1) no more filtering snvs -- this was moved to the  filter module 2) output file names changed
# Updated to .v3 for correcting the output of insertions in the bed file
# Updated to .v4 for correcting the sort order of snvs.hq and indels.hq

  

my $expected_dir = $test_dir . '/expected.v4/';

ok(-d $expected_dir, "expected results directory exists");

my $refbuild_id = 101947881;


my $mpileup_version = 'r963'; 

my $mpileup_command = Genome::Model::Tools::DetectVariants2::Samtools->create(
    reference_build_id => $refbuild_id,
    aligned_reads_input => $bam_input,
    version => $mpileup_version,
    params => "",
    output_directory => $test_working_dir_mpileup,
                    );

ok($mpileup_command, 'Created `gmt detect-variants2 samtools` command');

$mpileup_command->dump_status_messages(1);

ok($mpileup_command->execute, 'Executed `gmt detect-variants2 samtools` command');

#sleep 10000000000; turn the sleep on when you want to look at the results of the test


