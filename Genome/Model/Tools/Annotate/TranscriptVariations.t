#!/gsc/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 9;
use File::Compare;

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptVariations';

ok(-d $test_dir, "test data dir exists");

my $input = "$test_dir/input";

ok(-e $input, 'input exists');

my $ref_metrics = "$test_dir/known_output.metrics";
ok(-e $ref_metrics, 'ref metrics exists');

my $ref_transcript = "$test_dir/known_output.transcript";
ok(-e $ref_transcript, 'ref transcript exists');

my $output_base = "$test_dir/output";
my $command = "gt annotate transcript-variations --snv-file $input --output-file $output_base.transcript --summary-file $output_base.metrics";

is(system($command),0, "executed $command w/ return value of 0");

#my $variation = "$output_base.variation";
#ok(-e $variation, 'variation output exists');
#is(compare($variation, $ref_variation), 0, "variation and ref variation are the same");

my $metrics = "$output_base.metrics";
ok(-e $metrics, 'metrics output exists');
is(compare($metrics, $ref_metrics), 0, "metrics and ref metrics are the same")
    or diag(`sdiff $metrics $ref_metrics`);

my $transcript = "$output_base.transcript";
ok(-e $transcript, 'transcript output exists');
is(compare($transcript, $ref_transcript), 0, "transcript and ref transcript are the same")
    or diag(`sdiff $transcript $ref_transcript`);

unlink($metrics,$transcript);

