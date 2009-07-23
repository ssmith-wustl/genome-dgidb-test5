#!/gsc/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 9;
use File::Compare;
use above "Genome";

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptVariants';

ok(-d $test_dir, "test data dir exists");

my $input = "$test_dir/input";

ok(-e $input, 'input exists');

my $ref_transcript = "$test_dir/known_output.transcript";
ok(-e $ref_transcript, 'ref transcript exists');

my $output_base = "$test_dir/output";
my $command = "gt annotate transcript-variants --variant-file $input --output-file $output_base.transcript";

is(system($command),0, "executed $command w/ return value of 0");

my $transcript = "$output_base.transcript";
ok(-e $transcript, 'transcript output exists');

SKIP: {
    skip 'skipping comparison until default behavior is settled', 1;
is(compare($transcript, $ref_transcript), 0, "transcript and ref transcript are the same")
    or diag(`sdiff $transcript $ref_transcript`);
}

unlink($transcript);

my $command_build_id = "gt annotate transcript-variants --build-id 96232344 --variant-file $input --output-file $output_base.transcript";
is(system($command_build_id),0, "executed $command_build_id w/ return value of 0");

SKIP: {
   skip 'skipping for warnings', 2;

my $command_reference_transcripts = "gt annotate transcript-variants --reference-transcripts NCBI-human.ensembl/54_36p --variant-file $input --output-file $output_base.transcript";
is(system($command_reference_transcripts),0, "executed $command_reference_transcripts w/ return value of 0");


$command_reference_transcripts = "gt annotate transcript-variants --reference-transcripts NCBI-human.genbank/54_36p --variant-file $input --output-file $output_base.transcript";
is(system($command_reference_transcripts),0, "executed $command_reference_transcripts w/ return value of 0");

$command_reference_transcripts = "gt annotate transcript-variants --reference-transcripts NCBI-human.combined-annotation/54_36p --variant-file $input --output-file $output_base.transcript";
is(system($command_reference_transcripts),0, "executed $command_reference_transcripts w/ return value of 0");
}
