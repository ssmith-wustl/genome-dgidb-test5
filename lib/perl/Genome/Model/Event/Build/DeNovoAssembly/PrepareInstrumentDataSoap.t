#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome::Model::DeNovoAssembly::Test;
use File::Compare 'compare';
use Test::More;
use Data::Dumper;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData') or die;

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'soap de-novo-assemble',
);
ok($model, 'Got mock de novo assembly model') or die;

my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;

my @assembler_input_files = $build->existing_assembler_input_files;
ok(!@assembler_input_files, 'assembler input files do not exist');

my $soap = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData->create(
    build_id => $build->id
);
ok($soap, 'Created prepare inst data soap');
$soap->dump_status_messages(1);
ok($soap->execute, 'Execute prepare inst data soap');

@assembler_input_files = $build->existing_assembler_input_files;
is(@assembler_input_files, 2, 'created assembler input files');

my $example_build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($example_build, 'got example build') or die;
my @example_assembler_input_files = $build->existing_assembler_input_files;
is(@example_assembler_input_files, 2, 'created 2 assembler input files');
for ( my $i = 0; $i < 2; $i++ ) {
    is(
        File::Compare::compare($example_assembler_input_files[$i], $assembler_input_files[$i]),
        0, 
        "Assembler input fastq matches end one fastq file matches"
    );
}

#print $example_end_one_fastq.' '.$build->end_one_fastq_file."\n";
#print $example_end_two_fastq.' '.$build->end_two_fastq_file."\n";
#print $build->data_directory."\n"; <STDIN>;

done_testing();
exit;

