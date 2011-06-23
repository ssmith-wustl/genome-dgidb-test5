#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
use File::Basename;
require File::Compare;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PostAssemble') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_soap;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::Build->create( 
    model => $model,
    data_directory => $model->data_directory,
);
ok($build, 'Got de novo assembly build') or die;
my $example_build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($example_build, 'got example build') or die;

#link assembly.scafSeq file
my $example_scaf_seq_file = $example_build->soap_scaffold_sequence_file;
print $example_scaf_seq_file."\n";
ok(-s $example_scaf_seq_file, "Example scaffold sequence file exists") or die;
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
my $soap = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble->create(build_id =>$build->id, model => $model);
ok($soap, "Created soap post assemble") or die;
ok($soap->execute, "Executed soap post assemble") or die;

#print $build->data_directory."\n"; <STDIN>;
done_testing();
exit;

