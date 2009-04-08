#!/gsc/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 8;
use File::Compare;

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptVariantsSimple';

ok(-d $test_dir, "test data dir exists");

my $input = "$test_dir/input";

ok(-e $input, 'input exists');

my $ref_transcript = "$test_dir/known_output.transcript";
ok(-e $ref_transcript, 'ref transcript exists');

my $output_base = "$test_dir/output";
my $command = "gt annotate transcript-variants-simple --snv-file $input --output-file $output_base.transcript";

is(system($command),0, "executed $command w/ return value of 0");

my $transcript = "$output_base.transcript";
ok(-e $transcript, 'transcript output exists');
is(compare($transcript, $ref_transcript), 0, "transcript and ref transcript are the same")
    or diag(`sdiff $transcript $ref_transcript`);

unlink($transcript);

my $command_build_id = "gt annotate transcript-variants-simple --build-id 96232344 --snv-file $input --output-file $output_base.transcript";
is(system($command_build_id),0, "executed $command_build_id w/ return value of 0");

my $command_reference_transcripts = "gt annotate transcript-variants-simple --reference-transcripts NCBI-human.ensembl/52 --snv-file $input --output-file $output_base.transcript";
is(system($command_reference_transcripts),0, "executed $command_reference_transcripts w/ return value of 0");
