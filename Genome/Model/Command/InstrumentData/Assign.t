#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Sub::Override;

plan tests => 17;

#Genome::Model->class();
#my $override = Sub::Override->new();
#sub Genome::Model::Type::sub_classification_method_name {};

require_ok('Genome::Model::Command::InstrumentData::Assign');
&test_model_with_no_available_read_sets();
&test_new_model_and_add_new_read_sets();

# This tests both the case when there are compatible reads, but no new ones to add,
# and when there are no reads at all.  Since that determination is made in the model,
# not InstrumentData::Assign, by the model returning someting in $model->available_read_sets
sub test_model_with_no_available_read_sets {

    my $model = Test::MockObject->new();

    $model->set_always('genome_model_id', 12345);
    $model->set_always('id', 12345);
    $model->set_always('name', 'mock model');
    $model->set_always('subject_name', 'HMPB-080506_18AB_1A_tube1 large square agar plate');
    $model->set_always('subject_type', 'dna_resource_item');
    
    $model->set_list('compatible_input_items', ());
    $model->set_list('instrument_data', ());
    $model->set_list('available_instrument_data', ());
    $model->set_list('compatible_instrument_data', ());
    $model->set_list('unassigned_instrument_data', ());
    $model->set_isa('Genome::Model');

    $UR::Context::all_objects_loaded->{'Genome::Model'}->{'12345'} = $model;

    my $assign_id = Genome::Model::Command::InstrumentData::Assign->create( model => $model );
    ok($assign_id, 'Created an InstrumentData::Assign command for a model with no read sets at all');

    &_turn_off_messages($assign_id);

    my $worked = $assign_id->execute();
    ok(! $worked, 'Execute correctly returned false');

    my @status_messages = $assign_id->status_messages();
    ok(scalar(grep {m/No compatible instrument data found for model/} @status_messages),
       'It correctly complained about finding 0 read sets');
    
    my @warning_messages = $assign_id->warning_messages();
    is(scalar(@warning_messages), 0, 'No warning messages');
    my @error_messages = $assign_id->error_messages();
    is(scalar(@error_messages), 0, 'No error messages');
}

sub test_new_model_and_add_new_read_sets {
    my $override = Test::MockModule->new('Genome::InstrumentData');
    my @mocked_instr_data = map {
                        my $instr_data = Test::MockObject->new();
                        $instr_data->set_isa('Genome::InstrumentData::Solexa');
                        $instr_data->set_always('id', $_->{'id'});
                        $instr_data->set_always('sequencing_platform', 'solexa');
                        $instr_data->set_always('run_name', $_->{'run_name'});
                        $instr_data->set_always('subset_name', $_->{'subset_name'});
                        $instr_data;
                      }
                      ( {id => 'A', run_name => 'Foo', subset_name => 'Lane1' },
                        {id => 'B', run_name => 'Bar', subset_name => 'Lane2' } );

    $override->mock('get', sub{ return @mocked_instr_data});

    my $model = Test::MockObject->new();
    $model->set_isa('Genome::Model');
    $model->set_always('genome_model_id', 12345);
    $model->set_always('id', 12345);
    $model->set_always('name', 'Mock model');
    $model->set_always('subject_name', 'HMPB-080506_18AB_1A_tube1 large square agar plate');
    $model->set_always('subject_type', 'dna_resource_item');

    $model->set_list('instrument_data', ());
    $model->set_list('available_instrument_data', @mocked_instr_data);
    $model->set_list('compatible_instrument_data', @mocked_instr_data);
    $model->set_list('unassigned_instrument_data', @mocked_instr_data);
    $model->set_list('assigned_instrument_data', ());

    $UR::Context::all_objects_loaded->{'Genome::Model'}->{'12345'} = $model;
    Genome::Model->all_objects_are_loaded(1);
    Genome::Model::InstrumentDataAssignment->all_objects_are_loaded(1);

    my $assign_id = Genome::Model::Command::InstrumentData::Assign->create( model => $model, all => 1 );
    ok($assign_id, 'Created an InstrumentData::Assign command for a model without read sets, but we will add some');

    &_turn_off_messages($assign_id);

    my $worked = $assign_id->execute();
    ok($worked, 'Execute returned true');

    my @status_messages = $assign_id->status_messages();
    ok(scalar(grep { m/Attempting to assign all availble instrument data/ } @status_messages),
       'Status messages mentioned adding all instrument data');
    ok(scalar(grep { m/assigned to model/ } @status_messages) == 2, 'Saw 2 success messages for aassigning instrument data');

    my @warning_messages = $assign_id->warning_messages;
    is(scalar(@warning_messages), 0, 'Saw no warning messages');
    my @error_messages = $assign_id->error_messages;
    is(scalar(@error_messages), 0, 'Saw no warning messages');

    my @instrument_data = Genome::Model::InstrumentDataAssignment->is_loaded();
    @instrument_data = sort { $a->instrument_data_id cmp $b->instrument_data_id } @instrument_data;
    is(scalar(@instrument_data), 2, 'InstrumentData::Assign created 2 InstrumentDataAssignment objects');
    is($instrument_data[0]->instrument_data_id , 'A', 'First InstrumentDataAssignment has correct instrument_data_id');
    is($instrument_data[0]->first_build_id , undef, 'First InstrumentDataAssignment correctly has null first_build_id');
    is($instrument_data[1]->instrument_data_id , 'B', 'Second InstrumentDataAssignment has correct instrument_data_id');
    is($instrument_data[1]->first_build_id , undef, 'Second InstrumentDataAssignment correctly has null first_build_id');

    $_->delete foreach @instrument_data;
}
    
sub _turn_off_messages {
    my $cmd = shift;

    $cmd->dump_status_messages(0);
    $cmd->dump_warning_messages(0);
    $cmd->dump_error_messages(0);

    $cmd->queue_status_messages(1);
    $cmd->queue_warning_messages(1);
    $cmd->queue_error_messages(1);
}

#$HeadURL$
#$Id$
