#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
require File::Compare;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PostAssemble') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_velvet;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::Build->create( 
    model => $model
);
ok($build, 'Got de novo assembly build') or die;
ok($build->get_or_create_data_directory, 'resolved data dir');
my $example_build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($example_build, 'got example build') or die;

my $example_fastq = $example_build->existing_assembler_input_files;
my $base_name = File::Basename::basename($example_fastq);
symlink($example_fastq, $build->data_directory."/$base_name");
ok(-s $build->existing_assembler_input_files, 'Linked fastq file exists in tmp test dir') or die;

my $example_afg_file = $example_build->assembly_afg_file;
symlink($example_afg_file, $build->assembly_afg_file);
ok(-s $build->assembly_afg_file, 'Linked assembly afg file') or die;

my $example_sequences_file = $example_build->sequences_file;
symlink($example_sequences_file, $build->sequences_file);
ok(-s $build->sequences_file, 'Linked sequences file') or die;

my $example_contigs_fasta_file = $example_build->contigs_fasta_file;
symlink($example_contigs_fasta_file, $build->contigs_fasta_file);
ok(-s $build->contigs_fasta_file, 'Linked contigs.fa file') or die;

my $velvet = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble->create( build_id => $build->id, model => $model);
ok($velvet, 'Created post assemble velvet');

ok($velvet->execute, 'Execute post assemble velvet');
#TODO - use test suite velvet-solexa-build dir files (not have separate post asm files for test)
my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model/DeNovoAssembly/velvet_solexa_build_post_assemble_v4/edit_dir';

my @file_names_to_test = (qw/ 
    reads.placed readinfo.txt
    gap.txt contigs.quals contigs.bases
    reads.unplaced reads.unplaced.fasta
    supercontigs.fasta supercontigs.agp
    /);

foreach my $file (@file_names_to_test) {
    my $data_directory = $build->data_directory;
    ok(-e $test_data_dir."/$file", "Test data dir $file file exists");
    ok(-e $data_directory."/edit_dir/$file", "Tmp test dir $file file exists");
    ok(File::Compare::compare($data_directory."/edit_dir/$file", $test_data_dir."/$file") == 0, "$file files match")
        or diag("Failed to compare $data_directory/edit_dir/$file with $test_data_dir/$file");
}

#test zipped files
foreach ('collated.fasta.gz') {#, 'collated.fasta.qual.gz') {
    my $test_file = $test_data_dir."/$_";
    my $temp_file = $build->data_directory."/edit_dir/$_";

    ok(-e $test_file, "Test data dir $_ file exists");
    ok(-s $temp_file, "Tmp test dire $_ file exists");
    
    my @diff = `zdiff $test_file $temp_file`;
    is(scalar (@diff), 0, "Zipped $_ file matches");
}

#print $build->data_directory."/edit_dir/";<STDIN>;
done_testing();

exit;

