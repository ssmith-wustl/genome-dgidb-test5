#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More tests=>10;

use Genome::Model::Tools::Bmr::CalculateBmr;

my $module = 'Genome::Model::Tools::Bmr::CalculateBmr';
my $data_dir = $module; 
$data_dir =~ s/::/-/g;

$data_dir = "/gsc/var/cache/testsuite/data/$data_dir";
ok(-d $data_dir, "found data directory $data_dir");

my $wiggle_dir = $data_dir . '/in.wiggles';
ok(-e $wiggle_dir, "found expected input wiggle directory");

my $input_rois = $data_dir . '/in.rois';
ok(-e $input_rois, "found expected input roi file");

my $input_mutations = $data_dir . '/in.mutations';
ok(-e $input_mutations, "found expected input mutations file");

my $expected_output_table = $data_dir . '/table.out';
ok(-e $expected_output_table, "found expected output table");

my $expected_output_rejections = $data_dir . '/rejected.out';
ok(-e $expected_output_rejections, "found expected output rejected mutations");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok(-d $temp_dir, "temp directory made at $temp_dir");

my $test_output_table = "$temp_dir/test.output.table";
my $test_rejected_mutations = "$temp_dir/test.rejected.muts";

my $cmd = "chdir $temp_dir; gmt bmr calculate-bmr --mutation-maf $input_mutations --wiggle-file-dir $wiggle_dir --roi-bedfile $input_rois --output-file $test_output_table --rejected-mutations $test_rejected_mutations";
note($cmd);
my $rv = system($cmd);
$rv /= 256;
ok($rv == 0, "command runs successfully");

my @output_table_diff = `diff $expected_output_table $test_output_table`;
is(scalar(@output_table_diff),0,"test output table matches expected output table") or diag(@output_table_diff);

my @output_rejections_diff = `diff $expected_output_rejections $test_rejected_mutations`;
is(scalar(@output_rejections_diff),0,"test rejected mutations matches expected rejected mutations") or diag(@output_rejections_diff);

done_testing();
