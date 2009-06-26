#!/gsc/bin/perl

use strict;
use warnings;
use Data::Dumper;
#use Test::More 'no_plan';
use Test::More skip_all => "Broken from changes made to novel variations to move to new data and optionally find the data via data_directory instead of build. Fixing soon.";
use File::Compare;

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-NovelVariations';
ok(-d $test_dir, "test data dir exists");

my $input = "$test_dir/input";
ok(-e $input, 'input exists');

my $ref_output = "$test_dir/known_output.variation";
ok(-e $ref_output, 'ref variation exists');

my $output = "$test_dir/output";
my $command = "gt annotate novel-variations --variant-file $input --output-file $output";

is(system($command),0, "executed $command w/ return value of 0");

ok(-e $output, 'output exists');
is(compare($output, $ref_output), 0, "output and ref output are the same")
    or diag("sdiff $output $ref_output");

#unlink($output);

