#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet');

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;
ok(!-s $build->collated_fastq_file, 'Collated fastq file does not exist');

my $velvet = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet->create(
    build_id => $build->id
);
ok($velvet, 'Created prepare inst data velvet');
ok($velvet->execute, 'Execute prepare inst data velvet');
ok(-s $build->collated_fastq_file, 'Created collated fastq file');

my $example_fastq_file_for_model = Genome::Model::DeNovoAssembly::Test->example_fastq_file_for_model($model);
is( 
    compare($build->collated_fastq_file, $example_fastq_file_for_model), 
    0,
    'Generated and example fastq files match!',
);

is ($build->reads_attempted, 25000, "Reads attempted");
is ($build->read_length, 90, "Read length");

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
