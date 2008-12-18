#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 23;

my $bogus_id = 0;

&test_model_with_no_available_read_sets();
&test_new_model_and_add_new_read_sets();

# This tests both the case when there are compatible reads, but no new ones to add,
# and when there are no reads at all.  Since that determination is made in the model,
# not AddReads, by the model returning someting in $model->available_read_sets
sub test_model_with_no_available_read_sets {
    my $model = &_create_mock_model;
    $model->set_always('sequencing_platform','test_sequencing_platform'),
    $model->set_always('read_set_class_name', 'Genome::RunChunk::Solexa');
    $model->set_list('compatible_input_items', ());
    $model->set_list('compatible_instrument_data', ());
    $model->set_list('read_sets', ());
    $model->set_list('available_read_sets', ());

    my $add_reads = Genome::Model::Command::AddReads->create( model => $model );
    ok($add_reads, 'Created an AddReads command for a model with no read sets at all');

    &_turn_off_messages($add_reads);

    ok(!$add_reads->execute(), 'Execute correctly returned false');

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
    my $override = Test::MockModule->new('Genome::RunChunk::Solexa');
    # We're going to say add all, but there will really only  be one to add
    my @mocked_run_chunks = map {
                        my $run_chunk = Genome::RunChunk->create_mock(
                                                                      id => $_->{'id'},
                                                                      genome_model_run_id => $_->{'id'},
                                                                      run_name => $_->{'run_name'},
                                                                      subset_name => $_->{'subset_name'},
                                                                      sample_name => $_->{'sample_name'},
                                                                      sequencing_platform => $_->{'sequencing_platform'}
                                                                  );
                      }
                      ( {
                         id => 'A',
                         run_name => 'Foo',
                         subset_name => 'Lane1',
                         sample_name => 'test_sample_a',
                         sequencing_platform => 'solexa',
                     },
                        {
                         id => 'B',
                         run_name => 'Bar',
                         subset_name => 'Lane2',
                         sample_name => 'test_sample_b',
                         sequencing_platform => 'solexa',
                     },
                   ,);
    my @mocked_instrument_data = map {
        my $instrument_data = Genome::InstrumentData->create_mock(
                                                                  id => $_->{'id'},
                                                                  instrument_data_id => $_->{'id'},
                                                                  run_name => $_->{'run_name'},
                                                                  subset_name => $_->{'subset_name'},
                                                                  sample_name => $_->{'sample_name'},
                                                                  sequencing_platform => $_->{'sequencing_platform'}
                                                              );
    }
        ( {
           id => 'A',
           run_name => 'Foo',
           subset_name => 'Lane1',
           sample_name => 'test_sample_a',
           sequencing_platform => 'solexa',
       },
          {
           id => 'B',
           run_name => 'Bar',
           subset_name => 'Lane2',
           sample_name => 'test_sample_b',
           sequencing_platform => 'solexa',
       },
          ,);

    $override->mock('get_or_create_from_read_set',
                    sub {
                        shift @mocked_run_chunks;
                    });
    $override->mock('_desc_dw_obj', sub {''});

    my $model = &_create_mock_model;
    $model->set_always('sequencing_platform','solexa'),
    $model->set_always('read_set_class_name', 'Genome::RunChunk::Solexa');
    $model->set_list('read_sets', ());
    $model->set_list('available_read_sets', @mocked_run_chunks);
    $model->set_list('compatible_input_items', @mocked_run_chunks);
    $model->set_list('compatible_instrument_data', @mocked_instrument_data);
    $model->set_list('available_instrument_data', @mocked_instrument_data);

    Genome::Model->all_objects_are_loaded(1);
    Genome::Model::ReadSet->all_objects_are_loaded(1);

    my $add_reads = Genome::Model::Command::AddReads->create( model => $model, all => 1 );
    ok($add_reads, 'Created an AddReads command for a model without read sets, but we will add some');

    &_turn_off_messages($add_reads);

    ok($add_reads->execute(), 'Execute returned true');

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

    my @idas = Genome::Model::InstrumentDataAssignment->is_loaded();
    @idas = sort { $a->instrument_data_id cmp $b->instrument_data_id } @idas;
    is(scalar(@idas), 2, 'AddReads created 2 InstrumentDataAssignment objects');
    is($idas[0]->instrument_data_id , 'A', 'First InstrumentDataAssignment has correct instrument_data_id');
    is($idas[0]->first_build_id , undef, 'First InstrumentDataAssignment correctly has null first_build_id');
    is($idas[1]->instrument_data_id , 'B', 'Second InstrumentDataAssignment has correct instrument_data_id');
    is($idas[1]->first_build_id , undef, 'Second InstrumentDataAssignment correctly has null first_build_id');
}

sub _create_mock_model {
    my $pp = Genome::ProcessingProfile->create_mock(
                                                    id => --$bogus_id,
                                                    name => 'test_pp_name',
                                                );
    my $model = Genome::Model->create_mock(
                                           id => --$bogus_id,
                                           genome_model_id => $bogus_id,
                                           name => 'test_model_name',
                                           subject_name => 'test_subject_name',
                                           subject_type => 'test_subject_type',
                                           processing_profile_id => $pp->id,
                                       );
    return $model;
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
