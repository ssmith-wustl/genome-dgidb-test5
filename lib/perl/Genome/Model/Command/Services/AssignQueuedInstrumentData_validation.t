#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';

require Genome::InstrumentData::Solexa;
use Test::More tests => 24;
use Test::MockObject;

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
    target_region_set_name => 'validation-test',
    index_sequence => 'GTTAC',
);
ok($instrument_data_1, 'Created an instrument data');

my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get(name => 'NCBI-human-build36');
isa_ok($ref_seq_build, 'Genome::Model::Build::ImportedReferenceSequence') or die;


my $fl = Genome::FeatureList->__define__(
    id => 'ABCDEFG',
    name => 'validation-test',
    format => 'true-BED',
    content_type => 'validation',
    reference => $ref_seq_build,
);

my $processing_profile = Genome::ProcessingProfile::ReferenceAlignment->create(
    dna_type => 'genomic dna',
    name => 'AQID-test-pp',
    read_aligner_name => 'bwa',
    sequencing_platform => 'solexa',
    read_aligner_params => '#this is a test',
    transcript_variant_annotator_version => 1,
);
ok($processing_profile, 'Created a processing_profile');

my $pse_1 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12345',
    ps_id => 3733,
    ei_id => '464681',
);

my $sv_model = Genome::Model::SomaticValidation->__define__(
    name => 'test-validation-model',
    target_region_set => $fl,
    design_set => $fl,
    tumor_sample => $instrument_data_1->sample,
    subject => $instrument_data_1->sample->source,
    reference_sequence_build => $ref_seq_build,
);

$pse_1->add_param('instrument_data_type', 'solexa');
$pse_1->add_param('instrument_data_id', $instrument_data_1->id);
$pse_1->add_param('subject_class_name', 'Genome::Sample');
$pse_1->add_param('subject_id', $sample->id);

no warnings;
sub GSC::IndexIllumina::get {
    my $self = shift;
    return $ii;
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
is(scalar(keys %$new_models), 0, 'the cron created no models for validation');
is($sv_model->instrument_data, $instrument_data_1, 'the cron added the instrument data to the validation model');
my $models_changed_1 = $command_1->_existing_models_assigned_to;
is(scalar(keys %$models_changed_1), 1, 'data was reported assigned to an existing model');
is((values(%$models_changed_1))[0]->build_requested, 1, 'requested build');



my $sample1a = Genome::Sample->create(
    id => '-11',
    name => 'Pooled_Library_test-sample',
    common_name => 'normal',
    source_id => $individual->id,
);

my $library1a = Genome::Library->create(
    id => '-22',
    sample_id => $sample1a->id,
);


my $instrument_data_1a = Genome::InstrumentData::Solexa->create(
    id => '-1033',
    library_id => $library1a->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'validation-test',
    index_sequence => 'unknown',
);
ok($instrument_data_1a, 'Created an instrument data');

my $pse_1a = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12345678',
    ps_id => 3733,
    ei_id => '464681',
);

$pse_1a->add_param('instrument_data_type', 'solexa');
$pse_1a->add_param('instrument_data_id', $instrument_data_1a->id);
$pse_1a->add_param('subject_class_name', 'Genome::Sample');
$pse_1a->add_param('subject_id', $sample1a->id);

my $command_1a = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_1a, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_1a->dump_status_messages(1);
ok($command_1a->execute(), 'assign-queued-instrument-data executed successfully.');

is($pse_1a->pse_status, 'completed', 'pooled instrument data removed from queue');
ok(@{[$pse_1a->added_param('no_model_generation_attempted')]}, 'flag about skipping work added to pse');

my $fl2 = Genome::FeatureList->__define__(
    id => 'ABCDEFGH',
    name => 'validation-test-roi',
    format => 'true-BED',
    content_type => 'roi',
    reference => $ref_seq_build,
);

my $pse_2 = GSC::PSE::QueueInstrumentDataForGenomeModeling->create(
    pse_status => 'inprogress',
    pse_id => '-12346',
    ps_id => 3733,
    ei_id => '464681',
);

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
    target_region_set_name => 'validation-test-roi',
    index_sequence => 'GGGGG',
);

$pse_2->add_param('instrument_data_type', 'solexa');
$pse_2->add_param('instrument_data_id', $instrument_data_2->id);
$pse_2->add_param('subject_class_name', 'Genome::Sample');
$pse_2->add_param('subject_id', $sample->id);

my $command_2 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_2, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_2->dump_status_messages(1);
ok($command_2->execute(), 'assign-queued-instrument-data executed successfully.');

my $err = $command_2->error_message;
ok($err =~ 'validation-test-roi', 'reported error about feature-list');

is($pse_2->pse_status, 'inprogress', 'PSE still in progress');

$fl2->content_type(undef);
my $command_3 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create(
    test => 1,
);

isa_ok($command_3, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_3->dump_status_messages(1);
ok($command_3->execute(), 'assign-queued-instrument-data executed successfully.');

$err = $command_3->error_message;
ok($err =~ 'validation-test-roi', 'reported error about feature-list');

