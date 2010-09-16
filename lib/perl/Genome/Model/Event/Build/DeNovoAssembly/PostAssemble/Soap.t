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

#link assembly.scafSeq file
my $example_scaf_seq_file = Genome::Model::DeNovoAssembly::Test->example_scaffold_sequence_file_for_soap_model($model);
ok(-s $example_scaf_seq_file, "Example scaffold sequence file exists");
symlink($example_scaf_seq_file, $build->soap_scaffold_sequence_file) or die;
ok(-s $build->soap_scaffold_sequence_file, "Linked scaffold sequence file");

#link input fastq files for input stats
my $example_1_fastq_file = Genome::Model::DeNovoAssembly::Test->example_end_one_fastq_file_for_model($model);
ok(-s $example_1_fastq_file, "Example 1_fastq file exists");
symlink($example_1_fastq_file, $build->end_one_fastq_file) or die;
ok(-s $build->end_one_fastq_file, "Linked 1_fastq file");

my $example_2_fastq_file = Genome::Model::DeNovoAssembly::Test->example_end_two_fastq_file_for_model($model);
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
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model/DeNovoAssembly/soap_solexa_build_post_assemble_v1';
ok(-d $data_dir, "Test data dir exists");
foreach (qw/ contigs.bases supercontigs.fasta supercontigs.agp stats.txt/) {
    ok(-s $data_dir."/$_", "Test data dir $_ file exists");
    ok(-s $build->data_directory."/edit_dir/$_", "Build data dir $_ file exists");
    ok(File::Compare::compare($data_dir."/$_",$build->data_directory."/edit_dir/$_") == 0, "$_ files match");
}

#<STDIN>;

done_testing();

exit;
