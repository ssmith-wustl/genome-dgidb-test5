#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
require File::Compare;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Soap') or die;

#model
my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'soap',
);
ok($model, 'Got mock de novo assembly model') or die;

#build
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;

# example build
my $example_build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($example_build, 'got example build') or die;

#link assembly.scafSeq file
my $example_scaf_seq_file = $example_build->soap_scaffold_sequence_file;
ok(-s $example_scaf_seq_file, "Example scaffold sequence file exists");
symlink($example_scaf_seq_file, $build->soap_scaffold_sequence_file) or die;
ok(-s $build->soap_scaffold_sequence_file, "Linked scaffold sequence file");

#link input fastq files for input stats
my $example_1_fastq_file = $example_build->end_one_fastq_file;
ok(-s $example_1_fastq_file, "Example 1_fastq file exists");
symlink($example_1_fastq_file, $build->end_one_fastq_file) or die;
ok(-s $build->end_one_fastq_file, "Linked 1_fastq file");

my $example_2_fastq_file = $example_build->end_two_fastq_file;
ok(-s $example_2_fastq_file, "Example 2_fastq file exists");
symlink($example_2_fastq_file, $build->end_two_fastq_file) or die;
ok(-s $build->end_two_fastq_file, "Linked 2_fastq file");

#create build->data_directory.'/edit_dir for post asm output files
mkdir $build->data_directory.'/edit_dir';
ok(-d $build->data_directory.'/edit_dir', "Create build data dir edit_dir");

#create, execute
my $soap = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Soap->create(build_id =>$build->id);
ok($soap, "Created soap post assemble") or die;
ok($soap->execute, "Executed soap post assemble") or die;

#compare files
foreach my $file_name (qw/ contigs_fasta_file supercontigs_fasta_file supercontigs_agp_file stats_file /) {
    my $example_file = $example_build->$file_name;
    ok(-s $example_file, "Test data dir $example_file");
    my $file = $build->$file_name;
    ok(-s $file, "Build data dir $file");
    is(File::Compare::compare($example_file, $file), 0, "$file_name files match");
}

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;
