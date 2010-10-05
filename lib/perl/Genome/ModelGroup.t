#!/gsc/bin/perl
use strict;
use warnings;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use above "Genome";
use Test::More tests => 16;

#It is intended that nothing actually writes to it--this should just be to prevent allocations
my $test_data_dir = File::Temp::tempdir('Genome-ModelGroup-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

use_ok('Genome::ModelGroup');

my $model_group = Genome::ModelGroup->create(
  id => -12345,
  name => 'Testsuite_ModelGroup',
  convergence_model_params => {
      data_directory => $test_data_dir,
  },
);

ok($model_group, 'Got a model_group');
isa_ok($model_group, 'Genome::ModelGroup');

ok($model_group->convergence_model, 'Auto-generated associated Convergence model'); 

my ($test_model, $test_model_two) = setup_test_models();

my $add_command = Genome::ModelGroup::Command::Member::Add->create(
    model_group_id => $model_group->id,
    model_ids => join(',', $test_model_two->id, $test_model->id),
);

ok($add_command, 'created member add command');
ok($add_command->execute(), 'executed member add command');

my @models_in_group = $model_group->models; #get around UR's scalar context check
is(scalar @models_in_group, 2, 'group has two models');

my $remove_command = Genome::ModelGroup::Command::Member::Remove->create(
    model_group_id => $model_group->id,
    model_ids => $test_model->id
);

ok($remove_command, 'created member remove command');
ok($remove_command->execute(), 'executed member remove command');

@models_in_group = $model_group->models;
is(scalar @models_in_group, 1, 'group has one model');

# Create some test models with builds and all of their prerequisites
sub setup_test_models {
    my $test_profile = Genome::ProcessingProfile::ReferenceAlignment->create(
        name => 'test_profile',
        sequencing_platform => 'solexa',
        dna_type => 'cdna',
        read_aligner_name => 'bwa',
        snv_detector_name => 'samtools',
    ); 
    ok($test_profile, 'created test processing profile');
    
    my $test_sample = Genome::Sample->create(
        name => 'test_subject',
    );
    ok($test_sample, 'created test sample');
    
    my $test_instrument_data = Genome::InstrumentData::Solexa->create(
    );
    ok($test_instrument_data, 'created test instrument data');
    
    my $reference_sequence_build = Genome::Model::Build::ImportedReferenceSequence->get(name => 'NCBI-human-build36');
    isa_ok($reference_sequence_build, 'Genome::Model::Build::ImportedReferenceSequence') or die;

    my $test_model = Genome::Model->create(
        name => 'test_reference_aligment_model_mock',
        subject_name => 'test_subject',
        subject_type => 'sample_name',
        processing_profile_id => $test_profile->id,
        data_directory => $test_data_dir,
        reference_sequence_build => $reference_sequence_build,
    );
    ok($test_model, 'created test model');
     
    my $test_model_two = Genome::Model->create(
        name => 'test_reference_aligment_model_mock_two',
        subject_name => 'test_subject',
        subject_type => 'sample_name',
        processing_profile_id => $test_profile->id,
        data_directory => $test_data_dir,
        reference_sequence_build => $reference_sequence_build,
    );
    ok($test_model_two, 'created second test model');

    
    return ($test_model, $test_model_two);
}
