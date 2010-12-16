#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData') or die;

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet one-button',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;

my @assembler_input_files = $build->existing_assembler_input_files;
ok(!@assembler_input_files, 'assembler input files do not exist');

#create
my $velvet = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData->create(
    build_id => $build->id
);
ok($velvet, 'Created prepare inst data velvet');
$velvet->dump_status_messages(1);

#execute
ok($velvet->execute, 'Execute prepare inst data velvet');
ok(-s $build->collated_fastq_file, 'Created collated fastq file');

# check collated fastq
my $example_build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($example_build, 'got example build') or die;
my $example_fastq_file = $example_build->collated_fastq_file;
is( 
    compare($build->collated_fastq_file, $example_fastq_file), 
    0,
    'Generated and example fastq files match!',
);

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
