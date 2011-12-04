#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use above "Genome";
use File::Temp;
use Test::More;
use Data::Dumper;
use File::Compare;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan  tests => 4;
}

use_ok( 'Genome::Model::Tools::Vcf::CreateCrossSampleVcf');

my $refbuild_id = 101947881;
my $test_data_directory = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Vcf-CreateCrossSampleVcf";
my $region_file = $test_data_directory."/input/feature_list_3.bed.gz";

my @input_builds = map{ Genome::Model::Build->get($_)} (116552788,116559016,116559101);

# Updated to .v2 for correcting an error with newlines
my $expected_directory = $test_data_directory . "/expected_2";
my $test_output_base = File::Temp::tempdir('Genome-Model-Tools-Vcf-CreateCrossSampleVcf-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

my $ccsv_cmd = Genome::Model::Tools::Vcf::CreateCrossSampleVcf->create(
    output_directory => $test_output_base,
    builds => \@input_builds,
    max_files_per_merge => 10,
    roi_file => $region_file,
    roi_name => "TEST_ROI_NAME",
    wingspan => 500,
);

my $output_file = $test_output_base."/snvs.merged.vcf.gz";
my $expected_file = $expected_directory."/snvs.merged.vcf.gz";

ok($ccsv_cmd, "created CreateCrossSampleVcf object");
ok($ccsv_cmd->execute(), "executed CreateCrossSampleVcf");


#The files will have a timestamp that will differ. Ignore this but check the rest.
my $expected = `zcat $expected_file | grep -v fileDate`;
my $output = `zcat $output_file | grep -v fileDate`;

my $diff = Genome::Sys->diff_text_vs_text($output, $expected);
ok(!$diff, 'output matched expected result')
    or diag("diff results:\n" . $diff);
