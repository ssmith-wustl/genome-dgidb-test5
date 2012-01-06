#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 5;

use_ok('Genome::Model::Tools::Vcf::VcfToVariantMatrix');

my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Vcf-Vcf-To-Variant-Matrix/";
my $input_file = "$test_dir/vcf-to-variant-matrix.test.input";

my $expected_output_file ="$test_dir/vcf-to-variant-matrix.test.output";

my $output_file = Genome::Sys->create_temp_file_path;


my $command = Genome::Model::Tools::Vcf::VcfToVariantMatrix->create( vcf_file=> $input_file,
                                                                     output_file=>$output_file
                                                                 );
ok($command, 'Command created');
my $rv = $command->execute;
ok($rv, 'Command completed Successfully');
ok(-s $output_file, "output_file_created");

my $diff = Genome::Sys->diff_file_vs_file($output_file, $expected_output_file);
ok(!$diff, 'output matched expected result')
    or diag("diff results:\n" . $diff);

