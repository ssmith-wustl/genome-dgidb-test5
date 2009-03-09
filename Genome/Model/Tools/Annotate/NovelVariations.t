#!/gsc/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use File::Compare;

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-NovelVariations';
ok(-d $test_dir, "test data dir exists");

my $input = "$test_dir/input";
ok(-e $input, 'input exists');

my $ref_variation = "$test_dir/known_output.variation";
ok(-e $ref_variation, 'ref variation exists');

my $ref_metrics = "$test_dir/known_output.metrics";
ok(-e $ref_metrics, 'ref metrics exists');

my $output_base = "$test_dir/output";
my $command = "gt annotate novel-variations --snv-file $input --output-file $output_base.variation --summary-file $output_base.metrics";

is(system($command),0, "executed $command w/ return value of 0");

my $variation = "$output_base.variation";
ok(-e $variation, 'variation output exists');
is(compare($variation, $ref_variation), 0, "variation and ref variation are the same")
    or diag("sdiff $variation $ref_variation");

my $metrics = "$output_base.metrics";
ok(-e $metrics, 'metrics output exists');
is(compare($metrics, $ref_metrics), 0, "metrics and ref metrics are the same")
    or diag("sdiff $metrics $ref_metrics");

unlink($variation,$metrics);

