#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData');

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;
ok(!-s $build->collated_fastq_file, 'Collated fastq file does not exist');

#create
my $velvet = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData->create(
    build_id => $build->id
);
ok($velvet, 'Created prepare inst data velvet');
$velvet->dump_status_messages(1);

# read processor pipes
my $coverage = $model->processing_profile->coverage;
my $read_processor = $model->processing_profile->read_processor;
$model->processing_profile->coverage(undef);
$model->processing_profile->read_processor(undef);
is($velvet->_setup_read_processor($build->instrument_data), 'gmt fast-qual rename --matches qr{#.*/1$}=.b1,qr{#.*/2$}=.g1 --input %s --output %s --type-in illumina', 'pipe ok for no read processor w/o coverage');
$model->processing_profile->coverage($coverage);
is($velvet->_setup_read_processor($build->instrument_data), 'gmt fast-qual limit by-coverage --bases %s --metrics-file '.$velvet->_coverage_metrics_file.' --input %s --output PIPE --type-in illumina | gmt fast-qual rename --matches qr{#.*/1$}=.b1,qr{#.*/2$}=.g1 --input PIPE --output %s', 'pipe ok for no read processor w/ coverage');
$model->processing_profile->read_processor($read_processor);
$model->processing_profile->coverage(undef);
is($velvet->_setup_read_processor($build->instrument_data), 'gmt fast-qual trimmer by-length -trim-length 10 --input %s --output PIPE --type-in illumina | gmt fast-qual rename --matches qr{#.*/1$}=.b1,qr{#.*/2$}=.g1 --input PIPE --output %s', 'pipe ok for read processor w/o coverage');
$model->processing_profile->coverage($coverage);
is($velvet->_setup_read_processor($build->instrument_data), 'gmt fast-qual trimmer by-length -trim-length 10 --input %s --output PIPE --type-in illumina | gmt fast-qual limit by-coverage --bases %s --metrics-file '.$velvet->_coverage_metrics_file.' --input PIPE --output PIPE | gmt fast-qual rename --matches qr{#.*/1$}=.b1,qr{#.*/2$}=.g1 --input PIPE --output %s', 'pipe ok for read processor w/ coverage');

#execute
ok($velvet->execute, 'Execute prepare inst data velvet');
ok(-s $build->collated_fastq_file, 'Created collated fastq file');

# check collated fastq
my $example_fastq_file_for_model = Genome::Model::DeNovoAssembly::Test->example_fastq_file_for_model($model);
is( 
    compare($build->collated_fastq_file, $example_fastq_file_for_model), 
    0,
    'Generated and example fastq files match!',
);

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
