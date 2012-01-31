#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use Test::More tests => 6;

use above 'Genome';

use_ok('Genome::Model::Tools::Dbsnp::Import::Flatfile');

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Dbsnp-Import-Flatfile';
my $test_flat_file = "$test_data_dir/ds_flat_chY.txt";
my $test_output = "$test_data_dir/ds_flat_chY.txt.out";
ok(-e $test_flat_file, "test file $test_flat_file exists") || die;
ok(-e $test_output, "test file $test_output exists") || die;

my $command_output = Genome::Sys->create_temp_file_path();

my $cmd = Genome::Model::Tools::Dbsnp::Import::Flatfile->create(
    flatfile => $test_flat_file,
    output_file => $command_output,
); 

ok($cmd, 'created the importer');
ok($cmd->execute, 'importer ran successfully');

my $diff = Genome::Sys->diff_file_vs_file($test_output, $command_output);
ok(!$diff, 'returned file matches expected file')
    or diag("diff:\n" . $diff);
