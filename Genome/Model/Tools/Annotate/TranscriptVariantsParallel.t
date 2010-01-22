#!/gsc/bin/perl

# Currently, this tests G::M::T::A::TranscriptVariantsParallel.pm by comparing its output with 
# G::M::T::A::TranscriptVariants, failing if there are any differences

use strict;
use warnings;
use Test::More tests => 7;
use above "Genome";

# Check test directory
my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptVariantsParallel';
ok(-d $test_dir, "Test data directory exists");

# Check that reference output exists in test directory
my $reference_output = $test_dir . '/transcript_variants_output.out';
ok(-e $reference_output, "Reference output file exists");

# Check that the test variants file exists in test directory
my $test_variants_file = $test_dir . '/variants_short.tsv';
ok(-e $test_variants_file, "Test variants file exists");

# Split by line number test
my $number_output = $test_dir . "/number_output_$$"; 
my $number_diff = $test_dir . "/number_diff.txt";
my $number_cmd_obj = Genome::Model::Tools::Annotate::TranscriptVariantsParallel->create(
    variant_file => $test_variants_file,
    output_file => $number_output,
    split_by_number => 50,
    annotation_filter => "top",
);
$number_cmd_obj->execute() if $number_cmd_obj;
system("diff $number_output $reference_output > $number_diff");
ok(-s $number_output, "Transcript variants parallel (split by line number) produced output");
ok(-z $number_diff, "Output of transcript variants and transcript variants parallel (split by line number) are the same");
unlink $number_diff, $number_output;

# Split by chromosome test
my $chrom_output = $test_dir . "/chrom_output_$$";
my $chrom_diff = $test_dir . "/chrom_diff.txt";
my $chrom_cmd_obj = Genome::Model::Tools::Annotate::TranscriptVariantsParallel->create(
    variant_file => $test_variants_file,
    output_file => $chrom_output,
    split_by_chromosome => 1,
    annotation_filter => "top",
);
$chrom_cmd_obj->execute() if $chrom_cmd_obj;
system("diff $chrom_output $reference_output > $chrom_diff");
ok(-s $chrom_output, "Transcript variants parallel (split by chromosome) produced output");
ok(-z $chrom_diff, "Output of transcript variants and transcript variants parallel (split by chromosome) are the same");
unlink $chrom_diff, $chrom_output;
