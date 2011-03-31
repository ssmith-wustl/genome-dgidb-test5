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
use Test::More tests => 128;

use_ok('Genome::Model::Command::Services::AssignQueuedInstrumentData');

my $project = Genome::Site::WUGC::Project->create(
    setup_project_id => '-4',
    name             => 'AQID-test-project',
);

isa_ok($project, 'Genome::Site::WUGC::Project');

my $work_order = Genome::WorkOrder->create(
    id => '-1000',
    pipeline => 'Illumina',
    project_id => '-4',
);

isa_ok($work_order, 'Genome::WorkOrder');

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

no warnings;
sub GSC::PSE::QueueInstrumentDataForGenomeModeling::get_inherited_assigned_directed_setups_filter_on {
    my @a;
    push @a, $work_order;
    return @a;
}
use warnings;

my $command_1 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_1, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_1->dump_status_messages(1);

# Mock copy sequence files pse and its status
my $copy_sequence_pse = Test::MockObject->new;
$copy_sequence_pse->mock('pse_status', sub { 'inprogress' });
$ii->mock('get_copy_sequence_files_pse', sub { $copy_sequence_pse });

ok($command_1->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models = $command_1->_newly_created_models;
is(scalar(keys %$new_models), 3, 'the cron created three models');
is_deeply([sort map { $_->name } values %$new_models], [sort qw/ unknown-run.unknown-subset.prod-qc AQID-test-sample.prod-refalign AQID-test-sample.prod-refalign-1 /], 'the cron named the new models correctly');

my $models_changed = $command_1->_existing_models_assigned_to;
is(scalar(keys %$models_changed), 0, 'the cron did no work for the second PSE, since the first assigns all on creation');

my $old_models = $command_1->_existing_models_with_existing_assignments;
is(scalar(keys %$old_models), 2, 'the cron found models with data [for the second PSE] already assigned');

my @old_model_ids = keys(%$old_models);
my $new_model_1 = $new_models->{$old_model_ids[0]};
my $old_model_1 = $old_models->{$old_model_ids[0]};
is_deeply($new_model_1, $old_model_1, 'the first model created is the one reused');
ok($new_model_1->build_requested, 'the cron set the first new model to be built');

my $new_model_2 = $new_models->{$old_model_ids[1]};
my $old_model_2 = $old_models->{$old_model_ids[1]};
is_deeply($new_model_2, $old_model_2, 'the second model created is the one reused');
ok($new_model_2->build_requested, 'the cron set the second new model to be built');

my @models_for_sample = Genome::Model->get(
    subject_class_name => 'Genome::Sample',
    subject_id => $sample->id,
);
is(scalar(@models_for_sample), 3, 'found three models created for the subject');
ok(grep($_ eq $new_model_1, @models_for_sample), 'first model is the same one that the cron claims it created');
ok(grep($_ eq $new_model_2, @models_for_sample), 'second model is the same one that the cron claims it created');

my @instrument_data = $new_model_1->instrument_data;
is(scalar(@instrument_data), 2, 'the first new model has two instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2)], 'those two instrument data are the ones for our PSEs');

@instrument_data = $new_model_2->instrument_data;
is(scalar(@instrument_data), 2, 'the second new model has two instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2)], 'those two instrument data are the ones for our PSEs');

is($pse_1->pse_status, 'completed', 'first pse completed');
is($pse_2->pse_status, 'completed', 'second pse completed');

my ($pse_1_genome_model_id) = $pse_1->added_param('genome_model_id');
my ($pse_2_genome_model_id) = $pse_2->added_param('genome_model_id');

ok(grep($_->id == $pse_1_genome_model_id, ($new_model_1, $new_model_2)), 'genome_model_id parameter set correctly for first pse');
ok(grep($_->id == $pse_2_genome_model_id, ($new_model_1, $new_model_2)), 'genome_model_id parameter set correctly for second pse');

my $group = Genome::ModelGroup->get(name => 'apipe-auto AQID');
ok($group, 'auto-generated model-group exists');

my @members = $group->models;
ok(grep($_ eq $new_model_1, @members), 'group contains the first newly created model');
ok(grep($_ eq $new_model_2, @members), 'group contains the second newly created model');

my $instrument_data_3 = Genome::InstrumentData::Solexa->create(
    id => '-102',
    library_id => $library->id,
    flow_cell_id => 'TM-021',
    lane => '3',
    index_sequence => 'CGTACG',
    subset_name => '3-CGTACG',
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
    index_sequence => 'ACGTAC',
    subset_name => '3-ACGTAC',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'test-capture-data',
);

my $sample_pool = Genome::Sample->create(
    id => '-10001',
    name => 'AQID-test-sample-pooled',
    common_name => 'normal',
    taxon_id => $taxon->id,
    source_id => $individual->id,
);

my $library_pool = Genome::Library->create(
    id => '-10002',
    sample_id => $sample_pool->id,
);

my $instrument_data_pool = Genome::InstrumentData::Solexa->create(
    id => '-1003',
    library_id => $library_pool->id,
    flow_cell_id => 'TM-021',
    lane => '3',
    index_sequence => 'unknown',
    subset_name => '3-unknown',
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
is(scalar(keys %$new_models_2), 6, 'the cron created six new models (capture data causes two models to be created)');

my $models_changed_2 = $command_2->_existing_models_assigned_to;
is(scalar(keys %$models_changed_2), 2, 'data was assigned to existing models');

my $old_models_2 = $command_2->_existing_models_with_existing_assignments;
is(scalar(keys %$old_models_2), 2, 'after assigning to existing models found those models again in generic by-sample assignment');

my @new_models_2 = values(%$new_models_2);
my ($model_changed_2, $model_changed_3) = values(%$models_changed_2);
ok(!grep($_ eq $model_changed_2, @new_models_2), 'the models created are not the one reused');
is($model_changed_2, $new_model_1, 'the first reused model is the one created previously');
ok(!grep($_ eq $model_changed_3, @new_models_2), 'the models created are not the one reused');
is($model_changed_3, $new_model_2, 'the second reused model is the one created previously');

for my $m (@new_models_2, $model_changed_2, $model_changed_3) {
    ok($m->build_requested, 'the cron set the model to be built');
}

my @new_refalign_models = grep($_->name !~ /prod-qc$/, @new_models_2);
is(scalar(@new_refalign_models), 4, 'created four refalign capture models');

for my $m (@new_refalign_models) {

    ok($m->region_of_interest_set_name, 'the new model has a region_of_interest_set_name defined');

    my @instrument_data = $m->instrument_data;
    is(scalar(@instrument_data),1, 'only one instrument data assigned');
    is($instrument_data[0],$instrument_data_4,'the instrument data is the capture data');
}

@models_for_sample = Genome::Model->get(
    subject_class_name => 'Genome::Sample',
    subject_id => $sample->id,
);

is(scalar(@models_for_sample), 9, 'found 9 models created for the subject');

@instrument_data = $new_model_1->instrument_data;
is(scalar(@instrument_data), 3, 'the first new model has three instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2, $instrument_data_3)], 'those three instrument data are the ones for our PSEs');

@instrument_data = $new_model_2->instrument_data;
is(scalar(@instrument_data), 3, 'the second new model has three instrument data assigned');
is_deeply([sort(@instrument_data)], [sort($instrument_data_1, $instrument_data_2, $instrument_data_3)], 'those three instrument data are the ones for our PSEs');

is($pse_3->pse_status, 'completed', 'third pse completed');
is($pse_4->pse_status, 'completed', 'fourth pse completed');

my (@pse_3_genome_model_ids) = $pse_3->added_param('genome_model_id');
my (@pse_4_genome_model_ids) = $pse_4->added_param('genome_model_id');

is(scalar(@pse_3_genome_model_ids), 2, 'two genome_model_id parameters for third pse');
ok(grep($new_model_1->id, @pse_3_genome_model_ids) , 'first genome_model_id parameter set correctly for third pse');
for my $id (@pse_4_genome_model_ids){
    ok(grep($_->id eq $id, @new_models_2),  'genome_model_id parameter set correctly to match builds created for fourth pse');
}

my @members_2 = $group->models;
is(scalar(@members_2) - scalar(@members), 4, 'four subsequent models added to the group');


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
is(scalar(keys %$models_changed_3), 2, 'pse 5 added to existing non-capture models despite pp error');

my $old_models_3 = $command_3->_existing_models_with_existing_assignments;
is(scalar(keys %$old_models_3), 1, 'one other model was found with this data assigned');

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

ok(grep($new_model_1 , values %$models_changed_3), 'first run first original model was added');
ok(grep($new_model_2 , values %$models_changed_3), 'first run second original model was added');

is($pse_5->pse_status, 'inprogress', 'fifth pse inprogress (due to incomplete information)');
is($pse_6->pse_status, 'completed', 'sixth pse completed');

my ($pse_5_genome_model_id) = $pse_5->added_param('genome_model_id');
my ($pse_6_genome_model_id) = $pse_6->added_param('genome_model_id');

is($pse_6_genome_model_id, $new_de_novo_model->id, 'genome_model_id parameter set correctly for sixth pse');

##Cleanup failure case from previous test
$pse_5 = undef;
$instrument_data_5->delete;
##

my $sample_2 = Genome::Sample->create(
    id => '-70',
    name => 'TCGA-TEST-SAMPLE-01A-01D',
    common_name => 'normal',
    taxon_id => $taxon->id,
    source_id => $individual->id,
    nomenclature => 'TCGA-Test',
);
ok($sample_2, 'Created TCGA sample');

my $sample_3 = Genome::Sample->create(
    id => '-71',
    name => 'TCGA-TEST-SAMPLE-10A-01D',
    common_name => 'normal',
    taxon_id => $taxon->id,
    source_id => $individual->id,
    nomenclature => 'TCGA-Test',
);
ok($sample_3, 'Created TCGA sample pair');

my $library_2 = Genome::Library->create(
    id => '-7',
    sample_id => $sample_2->id,
);
isa_ok($library_2, 'Genome::Library');

my $instrument_data_7 = Genome::InstrumentData::Solexa->create(
    id => '-700',
    library_id => $library_2->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);
ok($instrument_data_7, 'Created an instrument data');

my $pse_7 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-7675309',
    ps_id => $ps->ps_id,
);

$pse_7->add_param('instrument_data_type', 'solexa');
$pse_7->add_param('instrument_data_id', $instrument_data_7->id);
$pse_7->add_param('subject_class_name', 'Genome::Sample');
$pse_7->add_param('subject_id', $sample_2->id);
$pse_7->add_param('processing_profile_id', $processing_profile->id);
$pse_7->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

my $command_4 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_4, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
ok($command_4->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models_4 = $command_4->_newly_created_models;
is(scalar(keys %$new_models_4), 6, 'the cron created six new models');
my @somatic_variation =  grep($_->isa("Genome::Model::SomaticVariation"), values %$new_models_4);
my @tumor = grep($_->subject_name eq  $sample_2->name, values %$new_models_4);
my @normal = grep($_->subject_name eq  $sample_3->name, values %$new_models_4);
ok(scalar(@somatic_variation) == 2, 'the cron created two somatic variation models');
ok(scalar(@tumor) == 4, 'the cron created tumor models');
ok(scalar(@normal) == 2, 'the cron created paired normal models');
for my $somatic_variation (@somatic_variation){
    ok(grep($_ == $somatic_variation->tumor_model, @tumor), 'somatic variation has the correct tumor model');
    ok(grep($_ == $somatic_variation->normal_model, @normal), 'somatic variation has the correct normal model');
}

is($pse_7->pse_status, 'completed', 'seventh pse completed');

my $library_3 = Genome::Library->create(
    id => '-9',
    sample_id => $sample_3->id,
);
isa_ok($library_3, 'Genome::Library');

my $instrument_data_8 = Genome::InstrumentData::Solexa->create(
    id => '-777',
    library_id => $library_3->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);
ok($instrument_data_8, 'Created an instrument data');

my $pse_8 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-7775309',
    ps_id => $ps->ps_id,
);

$pse_8->add_param('instrument_data_type', 'solexa');
$pse_8->add_param('instrument_data_id', $instrument_data_8->id);
$pse_8->add_param('subject_class_name', 'Genome::Sample');
$pse_8->add_param('subject_id', $sample_3->id);
$pse_8->add_param('processing_profile_id', $processing_profile->id);
$pse_8->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);


my $command_5 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_5, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
ok($command_5->execute(), 'assign-queued-instrument-data executed successfully.');
my $new_models_5 = $command_5->_newly_created_models;
is(scalar(keys %$new_models_5), 0, 'the cron created zero new models');
for my $normal (@normal){
    ok(scalar($normal->instrument_data), 'the cron assigned the new instrument data to the empty paired model');
}

###
my $sample_4 = Genome::Sample->create(
    id => '-80',
    name => 'TCGA-TEST-SAMPLE2-01A-01D',
    common_name => 'normal',
    taxon_id => $taxon->id,
    source_id => $individual->id,
    nomenclature => 'TCGA-Test',
);
ok($sample_4, 'Created TCGA sample');

my $sample_5 = Genome::Sample->create(
    id => '-81',
    name => 'TCGA-TEST-SAMPLE2-10A-01D',
    common_name => 'normal',
    taxon_id => $taxon->id,
    source_id => $individual->id,
    nomenclature => 'TCGA-Test',
);
ok($sample_5, 'Created TCGA sample pair');

my $library_4 = Genome::Library->create(
    id => '-11',
    sample_id => $sample_4->id,
);
isa_ok($library_4, 'Genome::Library');

my $library_5 = Genome::Library->create(
    id => '-10',
    sample_id => $sample_5->id,
);
isa_ok($library_5, 'Genome::Library');

my $instrument_data_9 = Genome::InstrumentData::Solexa->create(
    id => '-800',
    library_id => $library_4->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);
ok($instrument_data_9, 'Created an instrument data');

my $instrument_data_10 = Genome::InstrumentData::Solexa->create(
    id => '-801',
    library_id => $library_5->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
);
ok($instrument_data_10, 'Created an instrument data');

my $pse_9 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-7600000',
    ps_id => $ps->ps_id,
);
$pse_9->add_param('instrument_data_type', 'solexa');
$pse_9->add_param('instrument_data_id', $instrument_data_9->id);
$pse_9->add_param('subject_class_name', 'Genome::Sample');
$pse_9->add_param('subject_id', $sample_4->id);
$pse_9->add_param('processing_profile_id', $processing_profile->id);
$pse_9->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

my $pse_10 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-7600001',
    ps_id => $ps->ps_id,
);
$pse_10->add_param('instrument_data_type', 'solexa');
$pse_10->add_param('instrument_data_id', $instrument_data_10->id);
$pse_10->add_param('subject_class_name', 'Genome::Sample');
$pse_10->add_param('subject_id', $sample_5->id);
$pse_10->add_param('processing_profile_id', $processing_profile->id);
$pse_10->add_reference_sequence_build_param_for_processing_profile( $processing_profile, $ref_seq_build);

my $command_6 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_6, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
ok($command_6->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models_6 = $command_6->_newly_created_models;
$DB::single = 1;
is(scalar(keys %$new_models_6), 6, 'the cron created six new models (three on each processing profile)');
my @somatic_variation_2 =  grep($_->isa("Genome::Model::SomaticVariation"), values %$new_models_6);
my @tumor_2 = grep($_->subject_name eq  $sample_4->name, values %$new_models_6);
my @normal_2 = grep($_->subject_name eq  $sample_5->name, values %$new_models_6);
ok(scalar(@somatic_variation_2) == 2, 'the cron created a pair of somatic variation models');
ok(scalar(@tumor_2) == 4, 'the cron created tumor models');
ok(scalar(@normal_2) == 2, 'the cron created paired normal models');
for my $somatic_variation_2 (@somatic_variation_2){
    ok(grep($_ == $somatic_variation_2->tumor_model, @tumor_2), 'somatic variation has the correct tumor model');
    ok(grep($_ == $somatic_variation_2->normal_model, @normal_2), 'somatic variation has the correct normal model');
}
