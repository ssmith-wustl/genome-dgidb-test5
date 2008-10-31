#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 50;

ok(my $read_set = Genome::Model::ReadSet->get(read_set_id=> 2499312867, model_id=>2721044485), "Got a read_set");
isa_ok($read_set, "Genome::Model::ReadSet");

ok(my $read_set_alignment_directory = $read_set->read_set_alignment_directory, "Got the read_set_alignment_directory");
ok(-d $read_set_alignment_directory, "read_set_alignment_directory exists");

ok(my $new_read_set_alignment_directory = $read_set->new_read_set_alignment_directory, "Got the new_read_set_alignment_directory");
ok(!-d $new_read_set_alignment_directory, "new_read_set_alignment_directory exists");

ok(scalar($read_set->invalid) == 0, "Checked invalid, seems valid");

ok(my @alignment_file_paths = $read_set->alignment_file_paths, "Got the alignment_file_paths");
for my $file_path (@alignment_file_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @aligner_output_file_paths = $read_set->aligner_output_file_paths, "Got the aligner_output_file_paths");
for my $file_path (@aligner_output_file_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @poorly_aligned_reads_list_paths = $read_set->poorly_aligned_reads_list_paths, "Got the poorly_aligned_reads_list_paths");
for my $file_path (@poorly_aligned_reads_list_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @poorly_aligned_reads_fastq_paths = $read_set->poorly_aligned_reads_fastq_paths, "Got the poorly_aligned_reads_fastq_paths");
for my $file_path (@poorly_aligned_reads_fastq_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

SKIP: {
          skip "Not sure this is supposed to work for solexa", 1;
          ok(my @contaminants_file_path = $read_set->contaminants_file_path, "Got the contaminants_file_path");
          for my $file_path (@contaminants_file_path) {
              ok (-e $file_path, "file path $file_path exists");
          }
}

ok(my $read_length = $read_set->read_length, "Got the read length");
ok(my $total_read_count = $read_set->_calculate_total_read_count, "Got total read count");

ok(my @read_set_alignment_files_for_refseq = $read_set->read_set_alignment_files_for_refseq("22"), "Got the read_set_alignment_files_for_refseq");
for my $file_path (@read_set_alignment_files_for_refseq) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my $yaml_string = $read_set->yaml_string, "Got the yaml string");

ok(my $alignment_statistics = $read_set->get_alignment_statistics, "Got the alignment statistics");
ok($alignment_statistics->{total}, "alignment statistics has a total");
ok($alignment_statistics->{isPE}, "alignment statistics has a isPE");
ok($alignment_statistics->{mapped}, "alignment statistics has a mapped");
ok($alignment_statistics->{paired}, "alignment statistics has a paired");

