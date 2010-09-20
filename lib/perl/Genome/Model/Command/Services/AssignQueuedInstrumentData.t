#!/gsc/bin/perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';

use Test::More tests => 39;

use_ok('Genome::Model::Command::Services::AssignQueuedInstrumentData');

my $taxon = Genome::Taxon->get( species_name => 'human' );
my $individual = Genome::Individual->create(
    id => '-10',
    name => 'AQID-test-individual',
    common_name => 'AQID10',
    taxon_id => $taxon->id,
);

my $sample = Genome::Sample->create(
    id => '-1',
    name => 'AQID-test-sample',
    common_name => 'normal',
    taxon_id => $taxon->id,
    source_id => $individual->id,
);

#my $sample = Genome::Sample->get(name => 'TEST-patient1-sample1');
isa_ok($sample, 'Genome::Sample');

my $instrument_data_1 = Genome::InstrumentData::Solexa->create(
    id => '-100',
    sample_id => $sample->id,
    sample_name => $sample->name,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);

my $processing_profile = Genome::ProcessingProfile::ReferenceAlignment->create(
    dna_type => 'genomic dna',
    name => 'AQID-test-pp',
    read_aligner_name => 'bwa',
    sequencing_platform => 'solexa',
    read_aligner_params => '#this is a test',
);

my $ps = GSC::ProcessStep->get( process_to => 'queue instrument data for genome modeling' );

my $pse_1 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12345',
    ps_id => $ps->ps_id,
);

$pse_1->add_param('instrument_data_type', 'solexa');
$pse_1->add_param('instrument_data_id', $instrument_data_1->id);
$pse_1->add_param('subject_class_name', 'Genome::Sample');
$pse_1->add_param('subject_id', $sample->id);
$pse_1->add_param('processing_profile_id', $processing_profile->id);

my $instrument_data_2 = Genome::InstrumentData::Solexa->create(
    id => '-101',
    sample_id => $sample->id,
    sample_name => $sample->name,
    flow_cell_id => 'TM-021',
    lane => '2',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);

my $pse_2 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12346',
    ps_id => $ps->ps_id,
);

$pse_2->add_param('instrument_data_type', 'solexa');
$pse_2->add_param('instrument_data_id', $instrument_data_2->id);
$pse_2->add_param('subject_class_name', 'Genome::Sample');
$pse_2->add_param('subject_id', $sample->id);
$pse_2->add_param('processing_profile_id', $processing_profile->id);

my $command_1 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_1, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
ok($command_1->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models = $command_1->_newly_created_models;
is(scalar(keys %$new_models), 1, 'the cron created one model');

my $models_changed = $command_1->_existing_models_assigned_to;
is(scalar(keys %$models_changed), 0, 'the cron did no work for the second PSE, since the first assigns all on creation');

my $old_models = $command_1->_existing_models_with_existing_assignments;
is(scalar(keys %$old_models), 1, 'the cron found a model with data [for the second PSE] already assigned');

my ($new_model) = values(%$new_models);
my ($old_model) = values(%$old_models);
is($new_model, $old_model, 'the model created is the one reused');

ok($new_model->build_requested, 'the cron set the new model to be built');

my @models_for_sample = Genome::Model->get(
    subject_class_name => 'Genome::Sample',
    subject_id => $sample->id,
);
is(scalar(@models_for_sample), 1, 'found a model created for the subject');
is($models_for_sample[0], $new_model, 'that model is the same one the cron claims it created');

my @instrument_data = $new_model->instrument_data;
is(scalar(@instrument_data), 2, 'the new model has two instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2)], 'those two instrument data are the ones for our PSEs');

is($pse_1->pse_status, 'completed', 'first pse completed');
is($pse_2->pse_status, 'completed', 'second pse completed');

my $group = Genome::ModelGroup->get(name => 'apipe-auto AQID');
ok($group, 'auto-generated model-group exists');

my @members = $group->models;
ok(grep($_ eq $new_model, @members), 'group contains the newly created model');

my $instrument_data_3 = Genome::InstrumentData::Solexa->create(
    id => '-102',
    sample_id => $sample->id,
    sample_name => $sample->name,
    flow_cell_id => 'TM-021',
    lane => '3',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);

my $pse_3 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12347',
    ps_id => $ps->ps_id,
);
$pse_3->add_param('instrument_data_type', 'solexa');
$pse_3->add_param('instrument_data_id', $instrument_data_3->id);
$pse_3->add_param('subject_class_name', 'Genome::Sample');
$pse_3->add_param('subject_id', $sample->id);
$pse_3->add_param('processing_profile_id', $processing_profile->id);

my $instrument_data_4 = Genome::InstrumentData::Solexa->create(
    id => '-103',
    sample_id => $sample->id,
    sample_name => $sample->name,
    flow_cell_id => 'TM-021',
    lane => '3',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'test-capture-data',
);

my $pse_4 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12348',
    ps_id => $ps->ps_id,
);
$pse_4->add_param('instrument_data_type', 'solexa');
$pse_4->add_param('instrument_data_id', $instrument_data_4->id);
$pse_4->add_param('subject_class_name', 'Genome::Sample');
$pse_4->add_param('subject_id', $sample->id);
$pse_4->add_param('processing_profile_id', $processing_profile->id);

my $command_2 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_2, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
ok($command_2->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models_2 = $command_2->_newly_created_models;
is(scalar(keys %$new_models_2), 2, 'the cron created two new models (capture data causes two models to be created)');

my $models_changed_2 = $command_2->_existing_models_assigned_to;
is(scalar(keys %$models_changed_2), 1, 'data was assigned to an existing model');

my $old_models_2 = $command_2->_existing_models_with_existing_assignments;
is(scalar(keys %$old_models_2), 1, 'after assigning to existing models found that model again in generic by-sample assignment');

my @new_models_2 = values(%$new_models_2);
my ($model_changed_2) = values(%$models_changed_2);
ok(!grep($_ eq $model_changed_2, @new_models_2), 'the models created are not the one reused');
is($model_changed_2, $new_model, 'the reused model is the one created previously');

for my $m (@new_models_2, $model_changed_2) {
    ok($m->build_requested, 'the cron set the model to be built');
}

for my $m (@new_models_2) {
    ok($m->region_of_interest_set_name, 'the new model has a region_of_interest_set_name defined');

    my @instrument_data = $m->instrument_data;
    is(scalar(@instrument_data),1, 'only one instrument data assigned');
    is($instrument_data[0],$instrument_data_4,'the instrument data is the capture data');
}

@models_for_sample = Genome::Model->get(
    subject_class_name => 'Genome::Sample',
    subject_id => $sample->id,
);
is(scalar(@models_for_sample), 3, 'found 3 models created for the subject');

@instrument_data = $new_model->instrument_data;
is(scalar(@instrument_data), 3, 'the new model has three instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2, $instrument_data_3)], 'those three instrument data are the ones for our PSEs');

is($pse_3->pse_status, 'completed', 'third pse completed');
is($pse_4->pse_status, 'completed', 'fourth pse completed');

my @members_2 = $group->models;
is(scalar(@members_2) - scalar(@members), 2, 'two subsequent models added to the group');
