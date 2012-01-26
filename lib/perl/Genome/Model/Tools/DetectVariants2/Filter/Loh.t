#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Test::More;
use File::Compare;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 8;
}

use_ok('Genome::Model::Tools::DetectVariants2::Filter::Loh');

my $refbuild_id = 101947881;

my $test_input_dir      = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Filter-Loh';
my $tumor_snp_file      = $test_input_dir . '/snvs.hq.bed';
my $tumor_bam_file      = $test_input_dir. '/tumor.tiny.bam';
my $normal_bam_file     = $test_input_dir. '/normal.tiny.bam';
my $detector_directory  = $test_input_dir. '/varscan-somatic-2.2.4-';
my $detector_vcf_directory  = $test_input_dir. '/detector_vcf_result';

my $test_output_base     = File::Temp::tempdir('Genome-Model-Tools-Somatic-FilterLoh-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $test_output_dir = $test_output_base . '/filter';
my $hq_output_file      = $test_output_dir . '/snvs.hq.bed';
my $lq_output_file      = $test_output_dir . '/snvs.lq.bed';

my $expected_output_base = $test_input_dir. '/expected';
# Version 2 expects output files to be different due to adding snpfilter after samtools calls
my $expected_version = "v2";
my $expected_output_directory    = "$expected_output_base/$expected_version";

my $vcf_version = Genome::Model::Tools::Vcf->get_vcf_version;

my @expected_files = qw|    snvs.hq
                            snvs.hq.bed
                            snvs.lq
                            snvs.lq.bed
                            samtools.normal.snvs.hq.bed |;

# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};

my $detector_result = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir => $detector_directory,
    detector_name => 'Genome::Model::Tools::DetectVariants2::Sniper',
    detector_params => '',
    detector_version => 'awesome',
    aligned_reads => $tumor_bam_file,
    control_aligned_reads => $normal_bam_file,
    reference_build_id => $refbuild_id,
);

my $detector_vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Detector->__define__(
    input => $detector_result,
    output_dir => $detector_vcf_directory,
    aligned_reads_sample => "TEST",
    vcf_version => $vcf_version,
);

$detector_result->add_user(user => $detector_vcf_result, label => 'uses');

my $loh = Genome::Model::Tools::DetectVariants2::Filter::Loh->create(
    previous_result_id => $detector_result->id,
    output_directory => $test_output_dir,
);

ok($loh, 'created loh object');
ok($loh->execute(), 'executed loh object');

for my $file (@expected_files){
    my $expected_file = $expected_output_directory."/".$file;
    my $output_file = $test_output_dir."/".$file;
    is(compare($expected_file, $output_file), 0, 'output matched expected results');
}
