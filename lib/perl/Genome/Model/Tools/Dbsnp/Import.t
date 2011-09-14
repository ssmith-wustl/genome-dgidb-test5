#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 31;
}

use above 'Genome';

use_ok('Genome::Model::Tools::Dbsnp::Import');

my $test_dir = __FILE__ . '.d';
ok (-d $test_dir, "test directory $test_dir is present");
my $test_output = "$test_dir/output.bed";
ok(-e $test_output, "test output $test_output exists");

my @chromosomes = qw( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y MT );
for my $chromosome (@chromosomes){
    my $flatfile = "$test_dir/ds_flat_ch$chromosome.flat";
    ok(-e $flatfile, "test file $flatfile exists");
}

my $command_output = Genome::Sys->create_temp_file_path();

my $cmd = Genome::Model::Tools::Dbsnp::Import->create(
    output_file => $command_output,
    input_directory => $test_dir,
);

ok ($cmd, 'created the importer');
ok($cmd->execute, 'importer ran successfully');

#This is a hack, since I can't figure out how to make Joinx sort past chromosome, start, and stop
my $sorted_command_output = Genome::Sys->create_temp_file_path();
system("sort $command_output > $sorted_command_output");
my $sorted_test_output = Genome::Sys->create_temp_file_path();
system("sort $test_output > $sorted_test_output");

my $diff = Genome::Sys->diff_file_vs_file($sorted_test_output, $sorted_command_output);
ok(!$diff, 'returned file matches expected file')
    or diag("diff:\n" . $diff);
