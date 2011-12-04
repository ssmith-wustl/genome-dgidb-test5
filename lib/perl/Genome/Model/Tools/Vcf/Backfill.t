#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 5;

use_ok('Genome::Model::Tools::Vcf::Backfill');

my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Vcf-Backfill";
my $expected_base = "expected.v2";
my $expected_dir = "$test_dir/$expected_base";
my $expected_file = "$expected_dir/output.vcf";

my $output_file = Genome::Sys->create_temp_file_path;
my $input_vcf= "$test_dir/input.vcf.gz";
my $input_pileup = "$test_dir/pileup.in";

my $command = Genome::Model::Tools::Vcf::Backfill->create( vcf_file => $input_vcf, 
                                                           pileup_file  => $input_pileup,
                                                           output_file  => $output_file);

ok($command, 'Command created');
my $rv = $command->execute;
ok($rv, 'Command completed successfully');
ok(-s $output_file, "output file created");

# The files will have a timestamp that will differ. Ignore this but check the rest.
my $diff = Genome::Sys->diff_file_vs_file($output_file, $expected_file);
ok(!$diff, 'output matched expected result')
    or diag("diff results:\n" . $diff);
