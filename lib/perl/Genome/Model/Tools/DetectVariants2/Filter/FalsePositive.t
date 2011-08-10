#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 23;

# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};


use_ok('Genome::Model::Tools::DetectVariants2::Filter::FalsePositive');

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Filter-FalsePositive';
# v2 adjustment included input/output bed files as a base instead of varscan lines
my $expected_dir = join('/', $test_data_dir, 'expected.v3');

my $bam_file = join('/', $test_data_dir, 'tumor.tiny.bam');
my $detector_directory = join('/', $test_data_dir, 'varscan-somatic-2.2.4-.v2');
my $input_directory = join('/', $test_data_dir, "input");

my $expected_hq_file = join('/', $expected_dir, 'snvs.hq');
my $expected_lq_file = join('/', $expected_dir, 'snvs.lq');
my $expected_readcount_file = join('/', $expected_dir, 'readcounts');
ok(-s $expected_hq_file, "expected hq file output $expected_hq_file exists");
ok(-s $expected_lq_file, "expected lq file output $expected_lq_file exists");
ok(-s $expected_readcount_file, "expected readcount file output $expected_readcount_file exists");

my $output_base = File::Temp::tempdir('DetectVariants2-Filter-FalsePositiveXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $output_dir = $output_base . '/filter';
my $hq_output = join('/', $output_dir, 'snvs.hq');
my $lq_output = join('/', $output_dir, 'snvs.lq');
my $readcount_file = join('/', $output_dir, 'readcounts');

my $reference = Genome::Model::Build::ImportedReferenceSequence->get_by_name('NCBI-human-build36');
is($reference->id,101947881, 'Found correct reference sequence');

my $detector_result = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir => $detector_directory,
    detector_name => 'Genome::Model::Tools::DetectVariants2::VarscanSomatic',
    detector_params => '',
    detector_version => 'awesome',
    aligned_reads => $bam_file,
    reference_build_id => $reference->id,
);

my $filter_command = Genome::Model::Tools::DetectVariants2::Filter::FalsePositive->create(
    previous_result_id => $detector_result->id,
    output_directory => $output_dir,
    min_strandedness => 0.01,
    min_var_freq => 0.05,
    min_var_count => 4,
    min_read_pos => 0.10,
    max_mm_qualsum_diff => 50,
    max_var_mm_qualsum => 0,
    max_mapqual_diff => 30,
    max_readlen_diff => 25,
    min_var_dist_3 => 0.20,
    min_homopolymer => 5,
    bam_readcount_version => 0.3,
    bam_readcount_min_base_quality => 15, 
);
$filter_command->dump_status_messages(1);
isa_ok($filter_command, 'Genome::Model::Tools::DetectVariants2::Filter::FalsePositive', 'created filter command');
ok($filter_command->execute(), 'executed filter command');

ok(-s $hq_output, "hq output exists and has size"); 
ok(-s $lq_output, "lq output exists and has size"); 

my $output_diff = Genome::Sys->diff_file_vs_file($expected_hq_file, $hq_output);
ok(!$output_diff, 'output file matches expected result')
    or diag("diff:\n" . $output_diff);

my $filtered_diff = Genome::Sys->diff_file_vs_file($expected_lq_file, $lq_output);
ok(!$filtered_diff, 'filtered file matches expected result')
    or diag("diff:\n" . $filtered_diff);

$output_base = File::Temp::tempdir('DetectVariants2-Filter-FalsePositiveXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
$output_dir = $output_base . '/filter';
$hq_output = join('/', $output_dir, 'snvs.hq');
$lq_output = join('/', $output_dir, 'snvs.lq');
$readcount_file = join('/', $output_dir, 'readcounts');
my $filter_command2 = Genome::Model::Tools::DetectVariants2::Filter::FalsePositive->create(
    previous_result_id => $detector_result->id,
    output_directory => $output_dir,
    min_strandedness => 0.01,
    min_var_freq => 0.05,
    min_var_count => 4,
    min_read_pos => 0.10,
    max_mm_qualsum_diff => 50,
    max_var_mm_qualsum => 0,
    max_mapqual_diff => 30,
    max_readlen_diff => 25,
    min_var_dist_3 => 0.20,
    min_homopolymer => 5,
    bam_readcount_version => 0.3,
    bam_readcount_min_base_quality => 15, 
);
$filter_command2->dump_status_messages(1);
isa_ok($filter_command2, 'Genome::Model::Tools::DetectVariants2::Filter::FalsePositive', 'created second filter command');
ok($filter_command2->execute(), 'executed second filter command');

ok(-s $hq_output, "hq output exists and has size"); 
ok(-s $lq_output, "lq output exists and has size"); 

my $output_diff2 = Genome::Sys->diff_file_vs_file($expected_hq_file, $hq_output);
ok(!$output_diff2, 'output file matches expected result')
    or diag("diff:\n" . $output_diff2);

my $filtered_diff2 = Genome::Sys->diff_file_vs_file($expected_lq_file, $lq_output);
ok(!$filtered_diff2, 'filtered file matches expected result')
    or diag("diff:\n" . $filtered_diff2);

#for this test readcount file was supplied, so nothing to compare to.
$output_base = File::Temp::tempdir('DetectVariants2-Filter-FalsePositiveXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
$output_dir = $output_base . '/filter';
$hq_output = join('/', $output_dir, 'snvs.hq');
$lq_output = join('/', $output_dir, 'snvs.lq');
$readcount_file = join('/', $output_dir, 'readcounts');
my $filter_command3 = Genome::Model::Tools::DetectVariants2::Filter::FalsePositive->create(
    previous_result_id => $detector_result->id,
    output_directory => $output_dir,
    min_strandedness => 0.01,
    min_var_freq => 0.05,
    min_var_count => 4,
    min_read_pos => 0.10,
    max_mm_qualsum_diff => 50,
    max_var_mm_qualsum => 0,
    max_mapqual_diff => 30,
    max_readlen_diff => 25,
    min_var_dist_3 => 0.20,
    min_homopolymer => 5,
    bam_readcount_version => 0.3,
    bam_readcount_min_base_quality => 15, 
);
$filter_command3->dump_status_messages(1);
isa_ok($filter_command3, 'Genome::Model::Tools::DetectVariants2::Filter::FalsePositive', 'created second filter command');
ok($filter_command3->execute(), 'executed second filter command');

ok(-s $hq_output, "hq output exists and has size"); 
ok(-s $lq_output, "lq output exists and has size"); 

my $output_diff3 = Genome::Sys->diff_file_vs_file($expected_hq_file, $hq_output);
ok(!$output_diff3, 'output file matches expected result')
    or diag("diff:\n" . $output_diff3);

my $filtered_diff3 = Genome::Sys->diff_file_vs_file($expected_lq_file, $lq_output);
ok(!$filtered_diff3, 'filtered file matches expected result')
    or diag("diff:\n" . $filtered_diff3);
