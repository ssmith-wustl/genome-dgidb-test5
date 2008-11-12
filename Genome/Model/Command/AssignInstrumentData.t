#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Sub::Override;

plan tests => 18;

#Genome::Model->class();
#my $override = Sub::Override->new();
#sub Genome::Model::Type::sub_classification_method_name {};

&test_model_with_no_available_read_sets();
&test_new_model_and_add_new_read_sets();

# This tests both the case when there are compatible reads, but no new ones to add,
# and when there are no reads at all.  Since that determination is made in the model,
# not AddReads, by the model returning someting in $model->available_read_sets
sub test_model_with_no_available_read_sets {

    my $model = Test::MockObject->new();

    $model->set_always('genome_model_id', 12345);
    $model->set_always('id', 12345);
    $model->set_always('read_set_class_name', 'Genome::RunChunk::Solexa');
    
    $model->set_list('compatible_input_items', ());
    $model->set_list('read_sets', ());
    $model->set_list('available_read_sets', ());
    $model->set_isa('Genome::Model');

    $UR::Context::all_objects_loaded->{'Genome::Model'}->{'12345'} = $model;

    my $add_reads = Genome::Model::Command::AddReads->create( model => $model );
    ok($add_reads, 'Created an AddReads command for a model with no read sets at all');

    &_turn_off_messages($add_reads);

    my $worked = $add_reads->execute();
    ok(! $worked, 'Execute correctly returned false');

    my @status_messages = $add_reads->status_messages();
    ok(scalar(grep {m/Found 0 compatible read sets/} @status_messages),
       'It correctly complained about finding 0 read sets');
    ok(scalar(grep { m/No reads to add/ } @status_messages),
       'Said it had no reads to add');
    
    my @warning_messages = $add_reads->warning_messages();
    is(scalar(@warning_messages), 0, 'No warning messages');
    my @error_messages = $add_reads->error_messages();
    is(scalar(@error_messages), 0, 'No error messages');
}


sub test_new_model_and_add_new_read_sets {
 
    my $model = Test::MockObject->new();
    my $override = Test::MockModule->new('Genome::RunChunk::Solexa');
    # We're going to say add all, but there will really only  be one to add
    my @mocked_run_chunks = map {
                        my $run_chunk = Test::MockObject->new();
                        $run_chunk->set_isa('Genome::RunChunk');
                        $run_chunk->set_always('id', $_->{'id'});
                        $run_chunk->set_always('run_name', $_->{'run_name'});
                        $run_chunk->set_always('subset_name', $_->{'subset_name'});
                        $run_chunk;
                      }
                      ( {id => 'A', run_name => 'Foo', subset_name => 'Lane1' },
                        {id => 'B', run_name => 'Bar', subset_name => 'Lane2' } );


    $override->mock('get_or_create_from_read_set',
                    sub {
                        shift @mocked_run_chunks;
                    });
    $override->mock('_desc_dw_obj', sub {''});


    $model->set_always('genome_model_id', 12345);
    $model->set_always('id', 12345);
    $model->set_always('read_set_class_name', 'Genome::RunChunk::Solexa');

    $model->set_list('read_sets', ());
    $model->set_list('available_read_sets', 'A', 'B');
    $model->set_list('compatible_input_items', 'A', 'B');

    $UR::Context::all_objects_loaded->{'Genome::Model'}->{'12345'} = $model;
    Genome::Model->all_objects_are_loaded(1);
    Genome::Model::ReadSet->all_objects_are_loaded(1);

    my $add_reads = Genome::Model::Command::AddReads->create( model => $model, all => 1 );
    ok($add_reads, 'Created an AddReads command for a model without read sets, but we will add some');

    &_turn_off_messages($add_reads);

    my $worked = $add_reads->execute();
    ok($worked, 'Execute returned true');

    my @status_messages = $add_reads->status_messages();
    ok(scalar(grep { m/Adding all available reads to the model/ } @status_messages),
       'Status messages mentioned adding all reads');
    ok(scalar(grep { m/Added subset Lane1 of run Foo/ } @status_messages),
       'Saw success message for Lane1');

    ok(scalar(grep { m/Added subset Lane2 of run Bar/ } @status_messages),
       'Saw success message for Lane2');
    

    my @warning_messages = $add_reads->warning_messages;
    is(scalar(@warning_messages), 0, 'Saw no warning messages');
    my @error_messages = $add_reads->error_messages;
    is(scalar(@error_messages), 0, 'Saw no warning messages');

    my @readsets = Genome::Model::ReadSet->is_loaded();
    @readsets = sort { $a->read_set_id cmp $b->read_set_id } @readsets;
    is(scalar(@readsets), 2, 'AddReads created 2 ReadSet objects');
    is($readsets[0]->read_set_id , 'A', 'First ReadSet has correct read_set_id');
    is($readsets[0]->first_build_id , undef, 'First ReadSet correctly has null first_build_id');
    is($readsets[1]->read_set_id , 'B', 'Second ReadSet has correct read_set_id');
    is($readsets[1]->first_build_id , undef, 'Second ReadSet correctly has null first_build_id');

    $_->delete foreach @readsets;
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
