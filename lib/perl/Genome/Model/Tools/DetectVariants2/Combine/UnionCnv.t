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
    } else {
        plan tests => 5;
    }
};

use_ok( 'Genome::Model::Tools::DetectVariants2::Combine::UnionCnv');

my $test_data_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Combine-UnionCnv';
my $refbuild_id = 101947881;
my $tumor_bam_file  = $test_data_dir . '/flank_tumor_sorted.bam';
my $normal_bam_file  = $test_data_dir . '/flank_normal_sorted.bam';
my $input_directory_a = $test_data_dir."/cnv_input_a";
my $input_directory_b = $test_data_dir."/cnv_input_b";
my $expected_output = $test_data_dir."/expected";

my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-DetectVariants2-Combine-UnionCnv-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

my $union_cnv_object = Genome::Model::Tools::DetectVariants2::Combine::UnionCnv->create(
    input_directory_a           => $input_directory_a,
    input_directory_b           => $input_directory_b,
    aligned_reads_input => $tumor_bam_file,
    control_aligned_reads_input => $normal_bam_file,
    output_directory    => $test_output_dir,
    reference_build_id => $refbuild_id,
);

ok($union_cnv_object, 'created UnionCnv object');
ok($union_cnv_object->execute(), 'executed UnionCnv object');
