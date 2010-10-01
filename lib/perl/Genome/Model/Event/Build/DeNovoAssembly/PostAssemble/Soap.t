#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
use File::Basename;
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

#check link input fastq files
my @assembler_input_files = $example_build->existing_assembler_input_files;
for my $target ( @assembler_input_files ) {
    my $basename = File::Basename::basename($target);
    my $dest = $build->data_directory.'/'.$basename;
    symlink($target, $dest);
    ok(-s $dest, "linked $target to $dest");
}

#create build->data_directory.'/edit_dir for post asm output files
mkdir $build->data_directory.'/edit_dir';
ok(-d $build->data_directory.'/edit_dir', "Create build data dir edit_dir");

#create, execute
my $soap = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Soap->create(build_id =>$build->id);
ok($soap, "Created soap post assemble") or die;
ok($soap->execute, "Executed soap post assemble") or die;

#compare output files
my @gc_files = qw/ contigs_fasta_file supercontigs_fasta_file supercontigs_agp_file stats_file /;
my @pga_files = qw/ pga_agp_file pga_contigs_fasta_file pga_scaffolds_fasta_file /;

my @output_files = (@gc_files, @pga_files);

foreach my $file_name (@output_files) {
    my $example_file = $example_build->$file_name;
    ok(-s $example_file, "Test data dir $example_file");
    my $file = $build->$file_name;
    ok(-s $file, "Build data dir $file");
    is(File::Compare::compare($example_file, $file), 0, "$file_name files match");
}

#<STDIN>;

done_testing();

exit;
