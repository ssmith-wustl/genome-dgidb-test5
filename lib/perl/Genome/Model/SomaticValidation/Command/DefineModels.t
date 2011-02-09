#!/gsc/bin/perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';

use Test::More tests => 18;

use_ok('Genome::Model::SomaticValidation::Command::DefineModels');

my $tmpdir = File::Temp::tempdir('SomaticValidation-Command-DefineModelsXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my ($feature_list, $tumor_sample, $normal_sample, $somatic_build, $reference_alignment_pp, $somatic_validation_pp) = setup_test_data($tmpdir);

my $define_command_no_feature_list_for_somatic = Genome::Model::SomaticValidation::Command::DefineModels->create(
    somatic_build => $somatic_build,
    #region_of_interest_set => $feature_list,
    target_region_set => $feature_list,
    reference_alignment_processing_profile => $reference_alignment_pp,
    somatic_validation_processing_profile => $somatic_validation_pp,
);

isa_ok($define_command_no_feature_list_for_somatic, 'Genome::Model::SomaticValidation::Command::DefineModels', 'created define command');
my $result = $define_command_no_feature_list_for_somatic->execute;
ok(!$result, 'did not work without a subject for the feature-list');

$feature_list->subject($somatic_build);
my $define_command = Genome::Model::SomaticValidation::Command::DefineModels->create(
    somatic_build => $somatic_build,
    #region_of_interest_set => $feature_list,
    target_region_set => $feature_list,
    reference_alignment_processing_profile => $reference_alignment_pp,
    somatic_validation_processing_profile => $somatic_validation_pp,
);

isa_ok($define_command, 'Genome::Model::SomaticValidation::Command::DefineModels', 'created define command');



my $result = $define_command->execute;
ok($result, 'define command executed successfully') or die('test cannot continue without a model');

my $somatic_validation_model = Genome::Model->get($result);
isa_ok($somatic_validation_model, 'Genome::Model::SomaticValidation', 'created a somatic validation model');

my $tumor_model = $somatic_validation_model->tumor_model;
isa_ok($tumor_model, 'Genome::Model::ReferenceAlignment', 'created a tumor model');

my $normal_model = $somatic_validation_model->normal_model;
isa_ok($normal_model, 'Genome::Model::ReferenceAlignment', 'created a normal model');

is($tumor_model->subject, $tumor_sample, 'tumor model has correct subject');
is($normal_model->subject, $normal_sample, 'normal model has correct subject');

is($tumor_model->region_of_interest_set, $feature_list, 'tumor model has correct ROI list');
is($normal_model->region_of_interest_set, $feature_list, 'normal model has correct ROI list');

sub setup_test_data {
    my $tempdir = shift;

    my $simple_bed_text = "1\t3\t50\tmy_region_of_interest\n";
    my $bed_file_path = join('/', $tmpdir, 'roi.bed');
    Genome::Sys->write_file($bed_file_path, $simple_bed_text);

    my $reference_sequence = Genome::Model::Build::ImportedReferenceSequence->get_by_name('NCBI-human-build36');

    my $taxon = Genome::Taxon->get(species_name => 'human');

    my $individual = Genome::Individual->create(
        name => 'test individual for somatic-validation define-models',
        common_name => 'TEST-sv_define',
        taxon => $taxon,
    );

    my $tumor_sample = Genome::Sample->create(
        name => 'test tumor sample for somatic-validation define-models',
        common_name => 'tumor',
        source => $individual,
    );

    my $normal_sample = Genome::Sample->create(
        name => 'test normal sample for somatic-validation define-models',
        common_name => 'normal',
        source => $individual,
    );

    my $test_data = Genome::InstrumentData::Solexa->create(
        fwd_read_length => 100,
        rev_read_length => 100,
        read_length => 100,
        fwd_clusters => 1,
        rev_clusters => 1,
        clusters => 1,
    );

    my $reference_alignment_pp = Genome::ProcessingProfile::ReferenceAlignment->create(
        sequencing_platform => 'solexa',
        dna_type => 'genomic dna',
        read_aligner_name => 'bwa',
        snv_detector_name => 'test for somatic-validation define-models',
        name => 'test ref. align. pp for somatic-validation define-models',
    );

    my $somatic_pp = Genome::ProcessingProfile::Somatic->create(
        skip_sv => 1,
        only_tier_1 => 1,
        min_somatic_quality => '1',
        sv_detector_version => '0',
        sv_detector_params => '-',
        bam_window_version => 'x',
        bam_window_params => 'x',
        sniper_version => 'y',
        sniper_params => '-y',
        snv_detector_name => 'q',
        snv_detector_params => '-q',
        snv_detector_version => 'q',
        indel_detector_name => 'q',
        indel_detector_version => 'q',
        indel_detector_params => 'q',
        bam_readcount_version => 1,
        bam_readcount_params => 'x',
        require_dbsnp_allele_match => '1',
        min_mapping_quality => 'test for somatic-validation define-models',
        name => 'test somatic pp for somatic-validation define-models',
    );

    my $tumor_refalign_model = Genome::Model::ReferenceAlignment->create(
        processing_profile => $reference_alignment_pp,
        subject_id => $tumor_sample->id,
        subject_class_name => $tumor_sample->class,
        reference_sequence_build => $reference_sequence,
        name => 'intitial_normal_test_for_somatic-validation',
    );
    $tumor_refalign_model->add_instrument_data($test_data);

    my $tumor_build = Genome::Model::Build::ReferenceAlignment->create(
        model_id => $tumor_refalign_model->id
    );
    $tumor_build->_initialize_workflow;
    $tumor_build->status('Succeeded');
    $tumor_build->the_master_event->date_completed(UR::Time->now());

    my $normal_refalign_model = Genome::Model::ReferenceAlignment->create(
        processing_profile => $reference_alignment_pp,
        subject_id => $normal_sample->id,
        subject_class_name => $normal_sample->class,
        reference_sequence_build => $reference_sequence,
        name => 'intitial_tumor_test_for_somatic-validation',
    );
    $normal_refalign_model->add_instrument_data($test_data);

    my $normal_build = Genome::Model::Build::ReferenceAlignment->create(
        model_id => $normal_refalign_model->id
    );
    $normal_build->_initialize_workflow;
    $normal_build->status('Succeeded');
    $normal_build->the_master_event->date_completed(UR::Time->now());

    my $somatic_model = Genome::Model::Somatic->create(
        processing_profile => $somatic_pp,
        tumor_model => $tumor_refalign_model,
        normal_model => $normal_refalign_model,
    );

    my $somatic_build = Genome::Model::Build::Somatic->create(
        model_id => $somatic_model->id,
    );

    my $feature_list = Genome::FeatureList->create(
        name => 'test feature list for somatic-validation define-models',
        format => 'true-BED',
        reference => $reference_sequence,
        file_path => $bed_file_path,
        file_content_hash => Genome::Sys->md5sum($bed_file_path),
        #subject => $somatic_build, #set later in test
    );

    my $somatic_validation_pp = Genome::ProcessingProfile::SomaticValidation->create(
        name => 'test s.v. pp for somatic-validation define-models',
        samtools_version => 'test for somatic-validation define-models',
    );

    isa_ok($feature_list, 'Genome::FeatureList', 'created test feature-list');
    isa_ok($tumor_sample, 'Genome::Sample', 'created test tumor sample');
    isa_ok($normal_sample, 'Genome::Sample', 'created test normal sample');
    isa_ok($somatic_build, 'Genome::Model::Build::Somatic', 'created test somatic build');
    isa_ok($reference_alignment_pp, 'Genome::ProcessingProfile::ReferenceAlignment', 'created test ref. align. pp');
    isa_ok($somatic_validation_pp, 'Genome::ProcessingProfile::SomaticValidation', 'created test s.v. pp');

    return ($feature_list, $tumor_sample, $normal_sample, $somatic_build, $reference_alignment_pp, $somatic_validation_pp);
}
