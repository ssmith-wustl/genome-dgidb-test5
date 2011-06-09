#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

unless (`uname -a` =~ /x86_64/){
    die 'Must run on a 64 bit machine';
}

use_ok('Genome::Model::Event::Build::DeNovoAssembly::Assemble');

my $model = Genome::Model::DeNovoAssembly::Test->model_for_velvet;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::Build->create( 
    model => $model,
    data_directory => $model->data_directory,
);
ok($build, 'Got de novo assembly build') or die;
my $example_build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($example_build, 'got example build') or die;

# link input fastq files
my @assembler_input_files = $example_build->existing_assembler_input_files;
for my $target ( @assembler_input_files ) {
    my $basename = File::Basename::basename($target);
    my $dest = $build->data_directory.'/'.$basename;
    symlink($target, $dest);
    ok(-s $dest, "linked $target to $dest");
}

my $velvet = Genome::Model::Event::Build::DeNovoAssembly::Assemble->create( build_id => $build->id);

ok($velvet, 'Created assemble velvet');
ok($velvet->execute, 'Execute assemble velvet');

for my $file_name (qw/ contigs_fasta_file sequences_file assembly_afg_file /) {
    my $file = $build->$file_name;
    ok(-s $file, "Build $file_name exists");
    my $example_file = $example_build->$file_name;
    ok(-s $example_file, "Example $file_name exists");
    is( File::Compare::compare($file, $example_file), 0, "Generated $file_name matches example file");
}

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

