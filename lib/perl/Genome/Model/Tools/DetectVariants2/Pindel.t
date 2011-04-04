#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use Test::More;
use above 'Genome';

BEGIN {
    $ENV{NO_LSF} = 1;
}
my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    if($ENV{GSCAPP_RUN_LONG_TESTS}) {
        plan tests => 3;
    } else {
        plan skip_all => 'This test takes up to 10 minutes to run and thus is skipped.  Use `ur test run --long` to enable.';
    }
}


my $tumor =  "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Pindel/flank_tumor_sorted.bam";
my $normal = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Pindel/flank_normal_sorted.bam";

my $tmpdir = File::Temp::tempdir('PindelXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $refbuild_id = 101947881;

#$ref_seq_input =~ s/\/opt\/fscache//;

my $pindel = Genome::Model::Tools::DetectVariants2::Pindel->create(aligned_reads_input=>$tumor, 
                                                                   control_aligned_reads_input=>$normal,
                                                                   reference_build_id => $refbuild_id,
                                                                   output_directory => $tmpdir, 
                                                                   version => '0.4',);
ok($pindel, 'pindel command created');

$ENV{NO_LSF}=1;

my $rv = $pindel->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $output_indel_file = $pindel->output_directory . "/indels.hq.bed";

ok(-s $output_indel_file,'Testing success: Expecting a indel output file exists');
