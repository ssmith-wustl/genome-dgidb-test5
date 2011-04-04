#!/gsc/bin/perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}=1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}=1;
    $ENV{NO_LSF}=1;
}

use Parse::RecDescent qw/RD_ERRORS RD_WARN RD_TRACE/;
use Data::Dumper;
use Test::More tests => 2;
use above 'Genome';

#Parsing tests
my $det_class_base = 'Genome::Model::Tools::DetectVariants2';
my $dispatcher_class = "${det_class_base}::Dispatcher";

my $refbuild_id = 101947881;

my $tumor_bam = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Dispatcher/flank_tumor_sorted.bam";
my $normal_bam = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Dispatcher/flank_normal_sorted.bam";

# Test dispatcher for running a single detector followed by a single filter case
my $test_working_dir = File::Temp::tempdir('DetectVariants2-Dispatcher-filterXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $filter_test = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r599 filtered by snp-filter v1',
    output_directory => $test_working_dir,
    reference_build_id => $refbuild_id,
    aligned_reads_input => $tumor_bam,
    control_aligned_reads_input => $normal_bam,
);
ok($filter_test, "Object to test a filter case created");
ok($filter_test->execute, "Successfully executed test.");
