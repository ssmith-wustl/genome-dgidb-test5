#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 15;
use Carp::Always;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

#These get reused several times in this test--if later this test somehow depends on the contents of the directories make one for each
my $temp_model_data_dir = File::Temp::tempdir('t-Somatic_Model-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $temp_build_data_dir = File::Temp::tempdir('t_Somatic_Build-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

### Set up fake completed reference alignment builds

my $test_models = setup_test_models(); # { tumor => $model, normal => $model }

### Begin a Somatic test run

my $create_command = Genome::Model::Command::Define::Somatic->create(
    model_name => 'somatic_test',
    tumor_model_id => $test_models->{tumor}->id,
    normal_model_id => $test_models->{normal}->id,
    subject_name => 'test_subject',
    data_directory => $temp_model_data_dir,
);

ok($create_command, 'Created command to create Somatic model.');

ok($create_command->execute, 'Executed create command');

ok(my $somatic_model_id = $create_command->result_model_id, "Got result model id");
ok(my $somatic_model = Genome::Model->get($somatic_model_id), "Got the model from result model id");
isa_ok($somatic_model, "Genome::Model::Somatic");

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
    
    my $test_individual = Genome::Individual->create(
        common_name => 'TEST',
        name => 'test_individual',
    );
    ok($test_individual, 'created test individual');
    
    my $test_sample = Genome::Sample->create(
        name => 'test_subject',
        source_id => $test_individual->id,
    );
    ok($test_sample, 'created test sample');
    
    my $test_instrument_data = Genome::InstrumentData::Solexa->create(
    );
    ok($test_instrument_data, 'created test instrument data');
    
    my $test_model = Genome::Model->create(
        name => 'test_reference_aligment_model_TUMOR',
        subject_name => 'test_subject',
        subject_type => 'sample_name',
        processing_profile_id => $test_profile->id,
        data_directory => $temp_model_data_dir,
        reference_sequence_name => 'NCBI-human-build36'
    );
    ok($test_model, 'created test model');
    
    my $test_assignment = Genome::Model::InstrumentDataAssignment->create(
        model_id => $test_model->id,
        instrument_data_id => $test_instrument_data->id
    );
    ok($test_assignment, 'assigned data to model');
    
    #TODO Once we're using inputs, just use this line instead
    #ok($test_model->add_inst_data($test_instrument_data), 'assigned data to model');
    
    my $test_build = Genome::Model::Build->create(
        model_id => $test_model->id,
        data_directory => $temp_build_data_dir,
    );
    ok($test_build, 'created test build');
    
    my $test_model_two = Genome::Model->create(
        name => 'test_reference_aligment_model_mock_NORMAL',
        subject_name => 'test_subject',
        subject_type => 'sample_name',
        processing_profile_id => $test_profile->id,
        data_directory => $temp_model_data_dir,
        reference_sequence_name => 'NCBI-human-build36'
    );
    ok($test_model_two, 'created second test model');
    
    my $test_assignment_two = Genome::Model::InstrumentDataAssignment->create(
        model_id => $test_model_two->id,
        instrument_data_id => $test_instrument_data->id
    );
    ok($test_assignment_two, 'assigned data to second model');
    
    #TODO Once we're using inputs, just use this line instead
    #ok($test_model_two->add_inst_data($test_instrument_data), 'assigned data to model');
    
    my $test_build_two = Genome::Model::Build->create(
        model_id => $test_model_two->id,
        data_directory => $temp_build_data_dir,
    );
    ok($test_build_two, 'created second test build');
    
    return {tumor => $test_model, normal => $test_model_two};
}
