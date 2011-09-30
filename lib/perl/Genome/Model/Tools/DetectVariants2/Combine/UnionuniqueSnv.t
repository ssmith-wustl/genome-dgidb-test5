#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
};

use_ok( 'Genome::Model::Tools::DetectVariants2::Combine::UnionuniqueSnv');

my $test_data_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Combine-UnionuniqueSnv';
is(-d $test_data_dir, 1, 'test_data_dir exists') || die;

my $expected_output = $test_data_dir."/expected";
is(-d $expected_output, 1, 'expected_output exists') || die;

# FIXME Swap this for a test constructed reference build.
my $reference_build = Genome::Model::Build->get(101947881);
ok($reference_build, 'got reference_build');

my $aligned_reads         = join('/', $test_data_dir, 'flank_tumor_sorted.bam');
my $control_aligned_reads = join('/', $test_data_dir, 'flank_normal_sorted.bam');

my $detector_name_a = 'Genome::Model::Tools::DetectVariants2::Samtools';
my $detector_version_a = 'awesome';
my $output_dir_a = join('/', $test_data_dir, 'samtools-r599-');
my $detector_a = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir            => $output_dir_a,
    reference_build       => $reference_build,
    detector_name         => $detector_name_a,
    detector_version      => $detector_version_a,
    detector_params       => '',
    aligned_reads         => $aligned_reads,
    control_aligned_reads => $control_aligned_reads,
);
isa_ok($detector_a, 'Genome::Model::Tools::DetectVariants2::Result', 'detector_a');

my $detector_name_b    = 'Genome::Model::Tools::DetectVariants2::VarscanSomatic';
my $detector_version_b = 'awesome';
my $output_dir_b = join('/', $test_data_dir, 'varscan-somatic-2.2.4-');
my $detector_b = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir            => $output_dir_b,
    reference_build       => $reference_build,
    detector_name         => $detector_name_b,
    detector_version      => $detector_version_b,
    detector_params       => '',
    aligned_reads         => $aligned_reads,
    control_aligned_reads => $control_aligned_reads,
);
isa_ok($detector_b, 'Genome::Model::Tools::DetectVariants2::Result', 'detector_b');

my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-DetectVariants2-Combine-UnionuniqueSnv-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $output_symlink  = join('/', $test_output_dir, 'union-snv');
my $union_snv_object = Genome::Model::Tools::DetectVariants2::Combine::UnionuniqueSnv->create(
    input_a_id       => $detector_a->id,
    input_b_id       => $detector_b->id,
    output_directory => $output_symlink,
);
ok($union_snv_object, 'created UnionuniqueSnv object');
ok($union_snv_object->execute(), 'executed UnionuniqueSnv object');

my @files = qw| snvs.hq.bed
                snvs.lq.bed |;

for my $file (@files) {
    my $test_output = $output_symlink."/".$file;
    my $expected_output = $expected_output."/".$file;
    is(compare($test_output,$expected_output),0, "Found no difference between test output: ".$test_output." and expected output:".$expected_output);
}

done_testing();
