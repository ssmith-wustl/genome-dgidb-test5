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
    assembler_name => 'soap',
);
ok($model, 'Got mock de novo assembly model') or die;

my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);

ok($build, 'Got mock de novo assembly build') or die;
my @assembler_input_files = $build->assembler_input_files;
for my $assembler_input_file ( @assembler_input_files ) {
    ok(!-s $assembler_input_file, 'Assembler input file does not exist');
}

my $soap = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData->create(
    build_id => $build->id
);
ok($soap, 'Created prepare inst data soap');
$soap->dump_status_messages(1);
ok($soap->execute, 'Execute prepare inst data soap');

ok (-s $build->end_one_fastq_file, "Created end one fastq file");
ok (-s $build->end_two_fastq_file, "Created end two fastq file");

my $example_build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($example_build, 'got example build') or die;
my $example_end_one_fastq = $example_build->end_one_fastq_file;
is (compare($build->end_one_fastq_file, $example_end_one_fastq), 0, "Generated end one fastq file matches");
my $example_end_two_fastq = $example_build->end_two_fastq_file;
is (compare($build->end_two_fastq_file, $example_end_two_fastq), 0, "Generated end two fasta file matches");

#print $example_end_one_fastq.' '.$build->end_one_fastq_file."\n";
#print $example_end_two_fastq.' '.$build->end_two_fastq_file."\n";
#print $build->data_directory."\n"; <STDIN>;

done_testing();
exit;

