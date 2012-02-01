#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use Test::More;

use above 'Genome';

use_ok('Genome::InstrumentData::SxResult');

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-SxResult';

my ($instrument_data) = &setup_data();
my $read_processor = '';
my $output_file_count = 2;
my $output_file_type = 'sanger';

my %sx_result_params = (
    instrument_data_id => $instrument_data->id,
    read_processor => $read_processor,
    output_file_count => $output_file_count,
    output_file_type => $output_file_type,
    test_name => ($ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef),
);

my $sx_result = Genome::InstrumentData::SxResult->get_or_create(%sx_result_params);
isa_ok($sx_result, 'Genome::InstrumentData::SxResult', 'successful run');

my @read_processor_output_files = $sx_result->read_processor_output_files;
ok(@read_processor_output_files, 'produced read processor output files');

my $read_processor_output_metric_file = $sx_result->read_processor_output_metric_file;
my $read_processor_input_metric_file = $sx_result->read_processor_input_metric_file;
ok($read_processor_output_metric_file, 'produced read processor output metric file');
ok($read_processor_input_metric_file, 'produced read processor input metric file');

$sx_result_params{output_file_count} = 1;
my $sx_result3 = Genome::InstrumentData::SxResult->get(%sx_result_params);
ok(!$sx_result3, 'request with different (yet unrun) parameters returns no result');

my $sx_result4 = Genome::InstrumentData::SxResult->get_or_create(%sx_result_params);
isa_ok($sx_result4, 'Genome::InstrumentData::SxResult', 'successful run');
isnt($sx_result4, $sx_result, 'produced different result');

done_testing;

sub setup_data {
    my $sample = Genome::Sample->__define__(
        id => -1234,
        name => 'TEST-000',
    );

    ok($sample,'define sample') or die;

    my $lib = Genome::Library->__define__(
        id => -1235,
        name => $sample->name.'-testlibs1',
        sample_id => $sample->id,
        fragment_size_range => 180,
    );

    ok($lib, 'define library') or die;

    my $instrument_data = Genome::InstrumentData::Solexa->__define__(
        id => -6666,
        sequencing_platform => 'solexa',
        read_length => 101,
        subset_name => '1-AAAA',
        index_sequence => 'AAAA',
        run_name => 'XXXXXX/1-AAAAA',
        run_type => 'Paired',
        flow_cell_id => 'XXXXX',
        lane => 1,
        library => $lib,
        bam_path => $data_dir.'/inst_data/-6666/archive.bam',
        clusters => 44554,
        fwd_clusters => 44554,
        rev_clusters => 44554,
        analysis_software_version => 'not_old_illumina',
    );

    ok($instrument_data, 'define instrument data');
    ok($instrument_data->is_paired_end, 'inst data is paired');
    ok(-s $instrument_data->bam_path, 'inst data bam path');

    return ($instrument_data);
}
