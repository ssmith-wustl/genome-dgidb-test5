#!/gsc/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use File::Compare;

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TransAndNovel';

ok(-d $test_dir, "test data dir exists");

my $input = "$test_dir/input";

ok(-e $input, 'input exists');

my $ref_variation = "$test_dir/known_output.variation";
ok(-e $ref_variation, 'ref variation exists');

my $ref_metrics = "$test_dir/known_output.metrics";
ok(-e $ref_metrics, 'ref metrics exists');

my $ref_transcript = "$test_dir/known_output.transcript";
ok(-e $ref_transcript, 'ref transcript exists');

my $output_base = "$test_dir/output";
my $command = "gt annotate trans-and-novel -variant-file $input -report-file-base $output_base";

is(system($command),0, "executed $command w/ return value of 0");

my $variation = "$output_base.variation";
ok(-e $variation, 'variation output exists');
is(compare($variation, $ref_variation), 0, "variation and ref variation are the same");

my $metrics = "$output_base.metrics";
ok(-e $metrics, 'metrics output exists');
is(compare($metrics, $ref_metrics), 0, "metrics and ref metrics are the same");

my $transcript = "$output_base.transcript";
ok(-e $transcript, 'transcript output exists');
is(compare($transcript, $ref_transcript), 0, "transcript and ref transcript are the same");

unlink($variation,$metrics,$transcript);

=pod

=head1 NAME
ScriptTemplate - template for new perl script

=head1 SYNOPSIS

=head1 DESCRIPTION 

=cut

#$HeadURL$
#$Id$


