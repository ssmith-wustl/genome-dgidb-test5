#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 5;

use_ok('Genome::Model::Tools::Vcf::VcfFilter');

my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Vcf-VcfFilter";
my $expected_base = "expected.v1";
my $expected_dir = "$test_dir/$expected_base";
my $expected_file = "$expected_dir/output.vcf";

my $output_file = Genome::Sys->create_temp_file_path;
my $input_vcf = "$test_dir/input.vcf.gz";
my $hq_filter_file = "$test_dir/snvs.hq";

my $command= Genome::Model::Tools::Vcf::VcfFilter->create(
    output_file => $output_file,
    vcf_file => $input_vcf,
    filter_file => $hq_filter_file,
    filter_keep => 1,
    filter_name => "TEST",
    filter_description => "TEST",
    bed_input => 1,
);

ok($command, 'Command created');
my $rv = $command->execute;
ok($rv, 'Command completed successfully');
ok(-s $output_file, "output file created");

# The files will have a timestamp that will differ. Ignore this but check the rest.
my $diff = Genome::Sys->diff_file_vs_file($output_file, $expected_file);
ok(!$diff, 'output matched expected result')
    or diag("diff results:\n" . $diff);
