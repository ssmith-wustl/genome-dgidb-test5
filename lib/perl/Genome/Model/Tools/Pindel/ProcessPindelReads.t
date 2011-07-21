#!/usr/bin/env perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use File::Compare;
use Test::More;
use above 'Genome';

BEGIN {
    $ENV{NO_LSF} = 1;
}
my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 3;
}

my $tmpdir = File::Temp::tempdir('GMT-Pindel-ProcessPindelReads-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $test_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Pindel-ProcessPindelReads";
my $input_02 = "$test_data/indels_all_sequences.0.2";
my $input_04 = "$test_data/indels_all_sequences.0.4";
my $input_05 = "$test_data/indels_all_sequences.0.5";
my $output_02 = "$tmpdir/indels.hq.v02.bed";
my $output_04 = "$tmpdir/indels.hq.v04.bed";
my $output_05 = "$tmpdir/indels.hq.v05.bed";
my $output_06 = "$tmpdir/indels.hq.v06.bed";
my $big_output_05 = "$tmpdir/indels.hq.v05.bed.big_insertions";
my $expected_output_02 = "$test_data/expected/indels.hq.v02.bed";
my $expected_output_04 = "$test_data/expected/indels.hq.v04.bed";
my $expected_output_05 = "$test_data/expected/indels.hq.v05.bed";
my $expected_output_06 = "$test_data/expected/indels.hq.v06.bed";

my $refbuild_id = 101947881; 

# Test Pindel v0.5 output

my $ppr_cmd_06 = Genome::Model::Tools::Pindel::ProcessPindelReads->create(
                input_file => $input_05,
                output_file => $output_06,
                big_output_file => $big_output_05,
                reference_build_id => $refbuild_id,
                mode => 'to_bed', );

ok($ppr_cmd_06, 'process-pindel-reads command created');

my $result = $ppr_cmd_06->execute;
is($result, 1, 'Testing for execution.  Expecting 1.  Got: '.$result);

is(compare($output_06,$expected_output_06),0,'Output for v0.5 is identical to expected output');
