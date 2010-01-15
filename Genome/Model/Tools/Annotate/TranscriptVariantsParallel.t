#!/gsc/bin/perl

# Currently, this tests G::M::T::A::TranscriptVariantsParallel.pm by comparing its output with 
# G::M::T::A::TranscriptVariants, failing if there are any differences

use strict;
use warnings;
use Test::More tests => 7;
use above "Genome";

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptVariantsParallel';
ok(-d $test_dir, "Test data directory exists");

my $reference_output = $test_dir . '/transcript_variants_output.out';
ok(-e $reference_output, "Reference output file exists");

my $test_variants_file = $test_dir . '/variants_short.tsv';
ok(-e $test_variants_file, "Test variants file exists");

# Split by line number test
my $number_output = $test_dir . "/number_output_$$"; 
my $number_diff = $test_dir . "/number_diff.txt";
my $number_command = "gt annotate transcript-variants-parallel --variant-file $test_variants_file --output-file $number_output --split-by-number 50 --annotation-filter top --no-headers 1";
system($number_command);
system("diff $number_output $reference_output > $number_diff");
ok(-s $number_output, "Transcript variants parallel (split by line number) produced output");
ok(-z $number_diff, "Output of transcript variants and transcript variants parallel (split by line number) are the same");
unlink $number_diff, $number_output;

# Split by chromosome test
my $chrom_output = $test_dir . "/chrom_output_$$";
my $chrom_diff = $test_dir . "/chrom_diff.txt";
my $chrom_command = "gt annotate transcript-variants-parallel --variant-file $test_variants_file --output-file $chrom_output --split-by-chromosome 1 --annotation-filter top --no-headers 1";
system($chrom_command);
system("diff $chrom_output $reference_output > $chrom_diff");
ok(-s $chrom_output, "Transcript variants parallel (split by chromosome) produced output");
ok(-z $chrom_diff, "Output of transcript variants and transcript variants parallel (split by chromosome) are the same");
unlink $chrom_diff, $chrom_output;
