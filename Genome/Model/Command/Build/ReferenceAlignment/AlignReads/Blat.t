#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More skip_all => "Please move to Genome::InstrumentData::Command::Align::Blat";

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
    plan tests => 8;
    use_ok('Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat');
}

my $sff_file = '/gsc/var/cache/testsuite/data/Genome-Model-Command-Build-ReferenceAlignment-AlignReads-Blat';
# TODO: Add an sff_file to the read_set
my $bogus_id = 0;
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $pp = Genome::ProcessingProfile::ReferenceAlignment->create_mock(
                                                                    id => --$bogus_id,
                                                                );
my $model = Genome::Model::ReferenceAlignment->create_mock(
                                                           id => --$bogus_id,
                                                           genome_model_id => $bogus_id,
                                                           name => 'test_model_name',
                                                           processing_profile_id => $pp->id,
                                                           subject_type => 'test_subject_type',
                                                           subject_name => 'test_subject_name',
                                                           last_complete_build_id => undef,
                                                           read_aligner_name => 'blat',
                                                           reference_sequence_name => 'refseq-for-test',
                                                           type_name => 'reference alignment',
                                                       );
$model->set_always('alignment_directory', $tmp_dir .'/alignments');
$model->set_always('read_aligner_name','blat');
$model->set_always('read_aligner_params','');

my $instrument_data = Genome::InstrumentData::454->create_mock(
                                                        id => --$bogus_id,
                                                        genome_model_run_id => $bogus_id,
                                                        sample_name => 'test_sample_name',
                                                        sequencing_platform => '454',
                                                        run_name => 'test_run',
                                                        subset_name => 'test_subset',
                                                    );
isa_ok($instrument_data,'Genome::InstrumentData::454');
$instrument_data->mock('alignment_directory_for_aligner_and_refseq',
                       \&Genome::InstrumentData::alignment_directory_for_aligner_and_refseq);
$instrument_data->set_always('full_path',$tmp_dir);
$instrument_data->set_always('sff_file', $tmp_dir.'/test.sff');
$instrument_data->set_always('dump_to_file_system', 1);
$instrument_data->set_always('sample_type','dna');

my $ida = Genome::Model::InstrumentDataAssignment->create(
                                                          model_id => $model->id,
                                                          instrument_data_id => $instrument_data->id,
                                                          first_build_id => undef,
                                                      );
isa_ok($ida,'Genome::Model::InstrumentDataAssignment');
$instrument_data->mock('alignment_directory',
                       \&Genome::Model::InstrumentDataAssignment::alignment_directory);
my $blat_aligner = Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat->create(
                       model_id => $model->id,
                       instrument_data_id => $instrument_data->id,
                                                                                           );

isa_ok($blat_aligner,'Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat');
ok(!$blat_aligner->alignment_file,'no alignment file found');
ok(!$blat_aligner->aligner_output_file,'no aligner output file found');
ok(!$blat_aligner->execute,'does not execute yet');
ok(!$blat_aligner->verify_successful_completion,'does not verify yet');
exit;
