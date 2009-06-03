#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 26;

BEGIN {
    use_ok('Genome::Model::InstrumentDataAssignment');
}
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);

$ENV{GENOME_MODEL_ROOT} = $tmp_dir;

my $mock_id = 0;

############################
# go through all possiblities for creating an invalid instrument data object
# creating some mock objects along the way for use later to create a real instrument data
my $invalid_instrument_data;
eval{
    $invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create();
};
ok(!$invalid_instrument_data,'Failed to create instrument data with no params');

eval {
    $invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(instrument_data_id => --$mock_id);
};
ok(!$invalid_instrument_data,'Failed to create instrument data with no model_id');

eval {
    $invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(model_id => --$mock_id);
};
ok(!$invalid_instrument_data,'Failed to create instrument data with no instrument_data_id');

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                                           model_id => --$mock_id,
                                                                           instrument_data_id => --$mock_id,
                                                                       );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');
my @invalid_tags = $invalid_instrument_data->__errors__;
is(scalar(@invalid_tags),2,'Invalid instrument data with no model or run chunk objects');
eval {
    $invalid_instrument_data->read_length;
};
ok(scalar(grep {$_ =~ /^no instrument data for id/ } $@),'read_length failed because no run chunk found');


my $mock_instrument_data = Genome::InstrumentData::Solexa->create_mock(
                                                                       id => --$mock_id,
                                                                       instrument_data_id => $mock_id,
                                                                       sample_name => 'test_sample_name',
                                                                       run_name => 'test_run_name',
                                                                       subset_name => 'test_subset_name',
                                                                       sequencing_platform => 'solexa',
                                                       );
$mock_instrument_data->set_list('allocations');
$mock_instrument_data->set_always('calculate_alignment_estimated_kb_usage',undef);
$mock_instrument_data->set_always('sample_type','dna');

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                                           model_id => --$mock_id,
                                                                           instrument_data_id => $mock_instrument_data->id,
                                               );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');
@invalid_tags = $invalid_instrument_data->__errors__;
is(scalar(@invalid_tags),1,'Invalid instrument data with no model object');


my $mock_pp = Genome::ProcessingProfile::ReferenceAlignment::Solexa->create_mock(
                                                                                 id => --$mock_id,
                                                                             );
my $mock_model = Genome::Model::ReferenceAlignment->create_mock(
                                                                id => --$mock_id,
                                                                genome_model_id => $mock_id,
                                                                subject_name => 'test_sample_name',
                                                                subject_type => 'test_subject_type',
                                                                processing_profile_id => $mock_pp->id,
                                                                name => 'test_model_name',
                                                                read_aligner_name => 'test_read_aligner_name',
                                                                reference_sequence_name => 'test_reference_sequence_name',
                                                                type_name => 'reference alignment'
                                                            );
$mock_model->set_always('read_aligner_version',undef);
$mock_model->set_always('read_aligner_params',undef);

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                                           model_id => $mock_model->id,
                                                                           instrument_data_id => --$mock_id,
                                               );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');
@invalid_tags = $invalid_instrument_data->__errors__;
is(scalar(@invalid_tags),1,'Invalid instrument data with no run chunk object');

###############################
# create a real instrument data using the mock objects
my $new_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                                          instrument_data_id => $mock_instrument_data->id,
                                                                          model_id => $mock_model->id,
                                              );
isa_ok($new_instrument_data,'Genome::Model::InstrumentDataAssignment');


###############################
# Test methods that use indirect accessor on the run chunk object to calculate return values
$mock_instrument_data->mock('read_length', sub { return -1; } );
eval {
    $new_instrument_data->read_length;
};
ok(scalar(grep {$_ =~ /^Impossible value/} $@),'impossible value found for read length');
my $expected_read_length = 50;
$mock_instrument_data->mock('read_length', sub { return $expected_read_length; } );
is($new_instrument_data->read_length,$expected_read_length,'got expected read length: '. $expected_read_length);

my $expected_read_count = 1234567;
$mock_instrument_data->set_always('_calculate_total_read_count',$expected_read_count);
is($new_instrument_data->_calculate_total_read_count,$expected_read_count,'got expected read_count: '. $expected_read_count);

################################
# TODO: Add test if the run chunk is external, this requires a fake fastq file to parse



# TODO:
# copy real alignment files to the instrument_data_alignment_directory so accessors work correctly
# currently this is tested below using real data


ok($new_instrument_data->yaml_string,'got a yaml string');
ok($new_instrument_data->delete,'deleted test instrument data');

##################################################
# below tests rely on real run chunks and models #
##################################################
$ENV{GENOME_MODEL_ROOT} = undef;

ok(my $instrument_data = Genome::Model::InstrumentDataAssignment->get(instrument_data_id=> 2499312867, model_id=>2721044485), "Got a instrument_data");
isa_ok($instrument_data, "Genome::Model::InstrumentDataAssignment");
ok(scalar($instrument_data->__errors__) == 0, "Checked invalid, seems valid");

my $real_alignment = $instrument_data->alignment;
isa_ok($real_alignment,'Genome::InstrumentData::Alignment');

ok(my $alignment_directory = $instrument_data->alignment_directory, 'Got the alignment_directory');
ok(-d $alignment_directory, 'alignment_directory'. $alignment_directory .' exists');

ok(my $read_length = $instrument_data->read_length, "Got the read length");
ok(my $total_read_count = $instrument_data->_calculate_total_read_count, "Got total read count");
ok(my $yaml_string = $instrument_data->yaml_string, "Got the yaml string");



