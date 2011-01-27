#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';

require Genome::InstrumentData::Solexa;
use Test::More tests => 62;

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

my $library = Genome::Library->create(
    id => '-2',
    sample_id => $sample->id,
);

isa_ok($library, 'Genome::Library');

#my $sample = Genome::Sample->get(name => 'TEST-patient1-sample1');
isa_ok($sample, 'Genome::Sample');

my $ii = Test::MockObject->new();
$ii->set_always('copy_sequence_files_confirmed_successfully', 1);
no warnings;
*Genome::InstrumentData::Solexa::index_illumina = sub{ return $ii };
use warnings;
my $instrument_data_1 = Genome::InstrumentData::Solexa->create(
    id => '-100',
    library_id => $library->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);
ok($instrument_data_1, 'Created an instrument data');

my $processing_profile = Genome::ProcessingProfile::ReferenceAlignment->create(
    dna_type => 'genomic dna',
    name => 'AQID-test-pp',
    read_aligner_name => 'bwa',
    sequencing_platform => 'solexa',
    read_aligner_params => '#this is a test',
    transcript_variant_annotator_version => 1,
);
ok($processing_profile, 'Created a processing_profile');

my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get(name => 'NCBI-human-build36');
isa_ok($ref_seq_build, 'Genome::Model::Build::ImportedReferenceSequence') or die;

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
$pse_1->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

my $instrument_data_2 = Genome::InstrumentData::Solexa->create(
    id => '-101',
    library_id => $library->id,
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
$pse_2->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

my $command_1 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_1, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_1->dump_status_messages(1);
ok($command_1->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models = $command_1->_newly_created_models;
is(scalar(keys %$new_models), 2, 'the cron created two model');

my $models_changed = $command_1->_existing_models_assigned_to;
is(scalar(keys %$models_changed), 0, 'the cron did no work for the second PSE, since the first assigns all on creation');

my $old_models = $command_1->_existing_models_with_existing_assignments;
is(scalar(keys %$old_models), 1, 'the cron found a model with data [for the second PSE] already assigned');

my ($old_model_id) = keys(%$old_models);
my $new_model = $new_models->{$old_model_id};
my $old_model = $old_models->{$old_model_id};
is_deeply($new_model, $old_model, 'the model created is the one reused');

ok($new_model->build_requested, 'the cron set the new model to be built');

my @models_for_sample = Genome::Model->get(
    subject_class_name => 'Genome::Sample',
    subject_id => $sample->id,
);
is(scalar(@models_for_sample), 2, 'found two models created for the subject');
is($models_for_sample[0], $new_model, 'that model is the same one the cron claims it created');

my @instrument_data = $new_model->instrument_data;
is(scalar(@instrument_data), 2, 'the new model has two instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2)], 'those two instrument data are the ones for our PSEs');

is($pse_1->pse_status, 'completed', 'first pse completed');
is($pse_2->pse_status, 'completed', 'second pse completed');

my ($pse_1_genome_model_id) = $pse_1->added_param('genome_model_id');
my ($pse_2_genome_model_id) = $pse_2->added_param('genome_model_id');

is($pse_1_genome_model_id, $new_model->id, 'genome_model_id parameter set correctly for first pse');
is($pse_2_genome_model_id, $new_model->id, 'genome_model_id parameter set correctly for second pse');

my $group = Genome::ModelGroup->get(name => 'apipe-auto AQID');
ok($group, 'auto-generated model-group exists');

my @members = $group->models;
ok(grep($_ eq $new_model, @members), 'group contains the newly created model');

my $instrument_data_3 = Genome::InstrumentData::Solexa->create(
    id => '-102',
    library_id => $library->id,
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
$pse_3->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

my $instrument_data_4 = Genome::InstrumentData::Solexa->create(
    id => '-103',
    library_id => $library->id, 
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
$pse_4->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

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
is(scalar(@models_for_sample), 4, 'found 4 models created for the subject');

@instrument_data = $new_model->instrument_data;
is(scalar(@instrument_data), 3, 'the new model has three instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2, $instrument_data_3)], 'those three instrument data are the ones for our PSEs');

is($pse_3->pse_status, 'completed', 'third pse completed');
is($pse_4->pse_status, 'completed', 'fourth pse completed');

my (@pse_3_genome_model_ids) = $pse_3->added_param('genome_model_id');
my (@pse_4_genome_model_ids) = $pse_4->added_param('genome_model_id');

is(scalar(@pse_3_genome_model_ids), 1, 'one genome_model_id parameter for third pse');
is($pse_3_genome_model_ids[0], $new_model->id, 'genome_model_id parameter set correctly for third pse');
is_deeply([sort @pse_4_genome_model_ids], [sort map($_->id, @new_models_2)], 'genome_model_id parameter set correctly to match builds created for fourth pse');

my @members_2 = $group->models;
is(scalar(@members_2) - scalar(@members), 2, 'two subsequent models added to the group');


my $instrument_data_5 = Genome::InstrumentData::Solexa->create(
    id => '-104',
    library_id => $library->id,
    flow_cell_id => 'TM-021',
    lane => '5',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);

my $pse_5 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12349',
    ps_id => $ps->ps_id,
);
$pse_5->add_param('instrument_data_type', 'solexa');
$pse_5->add_param('instrument_data_id', $instrument_data_5->id);
$pse_5->add_param('subject_class_name', 'Genome::Sample');
$pse_5->add_param('subject_id', $sample->id);
$pse_5->add_param('processing_profile_id', $processing_profile->id);

#omitting this to test failure case
#$pse_5->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

my $de_novo_taxon = Genome::Taxon->get( species_name => 'Zinnia elegans' );

my $de_novo_individual = Genome::Individual->create(
    id => '-11',
    name => 'AQID-test-individual-ze',
    common_name => 'AQID11',
    taxon_id => $taxon->id,
);

my $de_novo_sample = Genome::Sample->create(
    id => '-22',
    name => 'AQID-test-sample-ze',
    common_name => 'normal',
    taxon_id => $de_novo_taxon->id,
    source_id => $de_novo_individual->id,
);

my $de_novo_library = Genome::Library->create(
    id=>'-33',
    sample_id=>$de_novo_sample->id
);

my $instrument_data_6 = Genome::InstrumentData::Solexa->create(
    id => '-105',
    library_id => $de_novo_library->id,
    flow_cell_id => 'TM-021',
    lane => '6',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);

my $de_novo_processing_profile = Genome::ProcessingProfile::DeNovoAssembly->create(
    name => 'AQID-test-de-novo-pp',
    assembler_name => 'velvet one-button',
    assembler_version => '0.7.57-64',
    sequencing_platform => 'solexa',
    read_processor => 'trimmer bwa-style --trim-qual-level 9000 --metrics-file this_is_a_test',
);

my $pse_6 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12350',
    ps_id => $ps->ps_id,
);
$pse_6->add_param('instrument_data_type', 'solexa');
$pse_6->add_param('instrument_data_id', $instrument_data_6->id);
$pse_6->add_param('subject_class_name', 'Genome::Sample');
$pse_6->add_param('subject_id', $de_novo_sample->id);
$pse_6->add_param('processing_profile_id', $de_novo_processing_profile->id);

my $command_3 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_3, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
ok($command_3->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models_3 = $command_3->_newly_created_models;
is(scalar(keys %$new_models_3), 1, 'the cron created another new model');

my $models_changed_3 = $command_3->_existing_models_assigned_to;
is(scalar(keys %$models_changed_3), 1, 'pse 5 added to existing non-capture model despite pp error');

my $old_models_3 = $command_3->_existing_models_with_existing_assignments;
is(scalar(keys %$old_models_3), 0, 'no other models were found with this data assigned');

my @models_for_de_novo_sample = Genome::Model->get(
    subject_class_name => 'Genome::Sample',
    subject_id => $de_novo_sample->id,
);
is(scalar(@models_for_de_novo_sample), 1, 'found 1 models created for the de-novo subject');

my($new_de_novo_model) = values %$new_models_3;
ok($new_de_novo_model->build_requested, 'the cron set the new model to be built');
my @de_novo_instrument_data = $new_de_novo_model->instrument_data;
is(scalar(@de_novo_instrument_data), 1, 'the new model has one instrument data assigned');
is($de_novo_instrument_data[0], $instrument_data_6, 'is the expected instrument data');

my($changed_model_3) = values %$models_changed_3;
is($changed_model_3, $new_model, 'latest addition is to the original model from the first run');

is($pse_5->pse_status, 'inprogress', 'fifth pse inprogress (due to incomplete information)');
is($pse_6->pse_status, 'completed', 'sixth pse completed');

my ($pse_5_genome_model_id) = $pse_5->added_param('genome_model_id');
my ($pse_6_genome_model_id) = $pse_6->added_param('genome_model_id');

is($pse_5_genome_model_id, undef, 'genome_model_id parameter remains unset on fifth pse');
is($pse_6_genome_model_id, $new_de_novo_model->id, 'genome_model_id parameter set correctly for sixth pse');
