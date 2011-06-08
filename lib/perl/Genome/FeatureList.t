#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1; #FeatureLists generate their own IDs, but this is still a good idea
};

use Test::More tests => 22;

use above 'Genome';

use_ok('Genome::FeatureList');

my $test_bed_file = __FILE__ . '.d/1.bed';
my $test_merged_bed_file = __FILE__ . '.d/1.merged.bed';
ok(-e $test_bed_file, 'test file ' . $test_bed_file . ' exists');
ok(-e $test_merged_bed_file, 'test file ' . $test_merged_bed_file . ' exists');

my $test_bed_file_md5 = Genome::Sys->md5sum($test_bed_file);

my $feature_list = Genome::FeatureList->create(
    name                => 'GFL test feature-list',
    format              => 'true-BED',
    content_type        => 'target region set',
    file_path           => $test_bed_file,
    file_content_hash   => $test_bed_file_md5,
);

ok($feature_list, 'created a feature list');
isa_ok($feature_list, 'Genome::FeatureList');
ok($feature_list->verify_file_md5, 'bed file md5 checks out');
is($feature_list->file_content_hash, $feature_list->verify_file_md5, 'verify_bed_file_md5 calculated the expected value');

my $file_path = $feature_list->file_path;
my $diff = Genome::Sys->diff_file_vs_file($test_bed_file, $file_path);
ok(!$diff, 'returned file matches expected file')
    or diag("diff:\n" . $diff);

my $merged_file = $feature_list->merged_bed_file;
ok(-s $merged_file, 'merged file created');
my $merged_diff = Genome::Sys->diff_file_vs_file($merged_file, $test_merged_bed_file);
ok(!$merged_diff, 'returned file matches expected file')
    or diag("diff:\n" . $merged_diff);

my $feature_list_with_bad_md5 = Genome::FeatureList->create(
    name                => 'GFL bad MD5 list',
    format              => 'true-BED',
    content_type        => 'target region set',
    file_path           => $test_bed_file,
    file_content_hash   => 'abcdef0123456789abcdef0123456789',
);
ok(!$feature_list_with_bad_md5, 'failed to produce a new object when MD5 was incorrect');

my $test_multitracked_1based_bed = __FILE__ . '.d/2.bed';
my $test_multitracked_1based_merged_bed = __FILE__ . '.d/2.merged.bed';
ok(-e $test_multitracked_1based_bed, 'test file ' . $test_multitracked_1based_bed . ' exists');
ok(-e $test_multitracked_1based_merged_bed, 'test file ' . $test_multitracked_1based_merged_bed . ' exists');

my $test_multitracked_1based_bed_md5 = Genome::Sys->md5sum($test_multitracked_1based_bed);

my $feature_list_2 = Genome::FeatureList->create(
    name                => 'GFL test multi-tracked 1-based feature-list',
    format              => 'multi-tracked 1-based',
    content_type        => 'target region set',
    file_path           => $test_multitracked_1based_bed,
    file_content_hash   => $test_multitracked_1based_bed_md5,
);
ok($feature_list_2, 'created multi-tracked 1-based feature list');
ok($feature_list_2->verify_file_md5, 'bed file md5 checks out');
is($test_multitracked_1based_bed_md5, $feature_list_2->verify_file_md5, 'verify_bed_file_md5 calculated the expected value');

my $merged_file_2 = $feature_list_2->merged_bed_file;
ok(-s $merged_file_2, 'merged file created');
my $merged_diff_2 = Genome::Sys->diff_file_vs_file($merged_file_2, $test_multitracked_1based_merged_bed);
ok(!$merged_diff_2, 'returned file matches expected file')
    or diag("diff:\n" . $merged_diff_2);

my $feature_list_3 = Genome::FeatureList->create(
    name => 'GFL test unknown format feature-list',
    format              => 'unknown',
    content_type        => 'target region set',
    file_path           => $test_multitracked_1based_bed,
    file_content_hash   => $test_multitracked_1based_bed_md5,
);
ok($feature_list_3, 'created unknown format feature list');
ok($feature_list_3->verify_file_md5, 'bed file md5 checks out');
my $merged_bed_file; 
eval {$merged_bed_file = $feature_list_3->merged_bed_file};
ok(!$merged_bed_file, 'refused to merge bed file with unknown format');
my $processed_bed_file;
eval{$processed_bed_file = $feature_list_3->processed_bed_file};
ok(!$processed_bed_file, 'attempt to process bed file did not return a bed file');
