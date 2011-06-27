#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_velvet;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::Build->create( 
    model => $model
);
ok($build, 'Got de novo assembly build') or die;
ok($build->get_or_create_data_directory, 'resolved data dir');
my $example_build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($example_build, 'got example build') or die;

my @assembler_input_files = $build->existing_assembler_input_files;
ok(!@assembler_input_files, 'assembler input files do not exist');

#create
my $velvet = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData->create(
    build_id => $build->id,
    model => $model,
);
ok($velvet, 'Created prepare inst data velvet');
$velvet->dump_status_messages(1);

#execute
ok($velvet->execute, 'Execute prepare inst data velvet');
ok(-s $build->collated_fastq_file, 'Created collated fastq file');

# check collated fastq
my $example_fastq_file = $example_build->collated_fastq_file;
ok(-s $example_fastq_file, 'example fastq exists');
is( 
    compare($build->collated_fastq_file, $example_fastq_file), 
    0,
    'Generated and example fastq files match!',
);

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

