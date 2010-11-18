#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Genome::Model::Test;
use Test::More;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_IDS} = 1;
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
eval {
    $invalid_instrument_data->read_length;
};
ok(scalar(grep {$_ =~ /^no instrument data for id/ } $@),'read_length failed because no run chunk found');


# have to use real id here cuz creating the input inside ida chokes
my ($mock_instrument_data) = Genome::InstrumentData::Sanger->get('2sep09.934pmaa1');

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                                           model_id => --$mock_id,
                                                                           instrument_data_id => $mock_instrument_data->id,
                                               );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');


my $mock_pp = Genome::ProcessingProfile::ReferenceAlignment::Solexa->create_mock(
                                                                                 id => --$mock_id,
                                                                             );

my $mock_model = Genome::Model::Test->create_basic_mock_model(type_name => 'reference alignment solexa');

#
# Inputs
#  are created when an ida is created, and also removed whe an ida is deleted.  
#  Create an extra input for the model, to make sure that correct inputs are deleted.
#
my $extra_input = $mock_model->add_input(
    name => 'instrument_data',
    value_class_name => 'Genome::InstrumentData::Sanger',
    value_id => '2sep09.934pmaa2',
);
ok($extra_input, 'Created extra input');

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                                           model_id => $mock_model->id,
                                                                           instrument_data_id => --$mock_id,
                                               );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');

###############################
# create a real instrument data using the mock objects
my $new_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                                          instrument_data_id => $mock_instrument_data->id,
                                                                          model_id => $mock_model->id,
                                              );
isa_ok($new_instrument_data,'Genome::Model::InstrumentDataAssignment');
isa_ok($new_instrument_data,'Genome::Model::InstrumentDataAssignment');

# FIXME - temporary - make sure input inst data is created
my @model_inputs = $mock_model->inst_data;
my @model_input_inst_data = $mock_model->inst_data;
ok(@model_input_inst_data, 'Created input for instrument data');


###############################
# Test methods that use indirect accessor on the run chunk object to calculate return values
SKIP: {
    skip("These methods will not be relevant after converting to inputs", 3);
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
}
# TODO:
# copy real alignment files to the instrument_data_alignment_directory so accessors work correctly
# currently this is tested below using real data


ok($new_instrument_data->yaml_string,'got a yaml string');
ok($new_instrument_data->delete,'deleted test instrument data');
# check that the input still exists
my @inputs = $mock_model->inputs();
ok(@inputs, 'Model still has input for other inst data');
is_deeply([ $extra_input->value_id ], [ map { $_->value_id } @inputs ], 'Removed input for this ida, but not other inst data input');

##################################################
# below tests rely on real run chunks and models #
##################################################
$ENV{GENOME_MODEL_ROOT} = undef;

ok(my $instrument_data = Genome::Model::InstrumentDataAssignment->get(instrument_data_id=> 2499312867, model_id=>2721044485), "Got a instrument_data");
isa_ok($instrument_data, "Genome::Model::InstrumentDataAssignment");
ok(scalar($instrument_data->__errors__) == 0, "Checked invalid, seems valid");

ok(my $read_length = $instrument_data->read_length, "Got the read length");
ok(my $total_read_count = $instrument_data->_calculate_total_read_count, "Got total read count");
ok(my $yaml_string = $instrument_data->yaml_string, "Got the yaml string");

done_testing();
exit;


