#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{NO_LSF} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use File::Path;
use File::Temp;
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    if(not $ENV{GSCAPP_RUN_LONG_TESTS}) {
        plan skip_all => 'This test takes up to 10 minutes to run and thus is skipped.  Use `ur test run --long` to enable.';
    }
}

use_ok('Genome::Model::Tools::DetectVariants2::PindelSingleGenome');

my $refbuild_id = 101947881;
my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get($refbuild_id);
ok($ref_seq_build, 'human36 reference sequence build') or die;

no warnings;
# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};
use warnings;

my $tumor =  "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Pindel/flank_tumor_sorted.bam";
my $normal = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Pindel/flank_normal_sorted.bam";

my $tmpbase = File::Temp::tempdir('PindelSingleGenomeXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $tmpdir = "$tmpbase/output";

my $pindel_sg = Genome::Model::Tools::DetectVariants2::PindelSingleGenome->create(aligned_reads_input=>$tumor, 
                                                                   reference_build_id => $refbuild_id,
                                                                   output_directory => $tmpdir, 
                                                                   version => '0.5',);
ok($pindel_sg, 'pindel command created');

$ENV{NO_LSF}=1;

$pindel_sg->dump_status_messages(1);
my $rv = $pindel_sg->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $output_indel_file = $tmpdir . "/indels.hq.bed";

ok(-s $output_indel_file,'Testing success: Expecting a indel output file exists');

done_testing();
exit;
