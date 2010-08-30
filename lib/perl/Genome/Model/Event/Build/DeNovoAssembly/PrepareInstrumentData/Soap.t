#!/gsc/bin/perl

use strict;
use warnings;

use Test::More skip_all => 'updating read processor';

use above 'Genome';
use Genome::Model::DeNovoAssembly::Test;
use File::Compare 'compare';
use Test::More;
use Data::Dumper;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Soap');


my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'soap',
);
ok($model, 'Got mock de novo assembly model') or die;

my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);

ok($build, 'Got mock de novo assembly build') or die;
ok(!-s $build->collated_fastq_file, 'Collated fastq file does not exist');

my $soap = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Soap->create(
    build_id => $build->id
);

ok($soap, 'Created prepare inst data soap');
ok($soap->execute, 'Execute prepare inst data soap');

ok (-s $build->end_one_fastq_file, "Created end one fastq file");
ok (-s $build->end_two_fastq_file, "Created end two fastq file");

my $example_end_one_fastq = Genome::Model::DeNovoAssembly::Test->example_end_one_fastq_file_for_model($model);
is (compare($build->end_one_fastq_file, $example_end_one_fastq), 0, "Generated end one fastq file matches");

my $example_end_two_fastq = Genome::Model::DeNovoAssembly::Test->example_end_two_fastq_file_for_model($model);
is (compare($build->end_two_fastq_file, $example_end_two_fastq), 0, "Generated end two fasta file matches");

#print $example_end_one_fastq.' '.$build->end_one_fastq_file."\n";
#print $example_end_two_fastq.' '.$build->end_two_fastq_file."\n";

#<STDIN>;

done_testing();

exit;
