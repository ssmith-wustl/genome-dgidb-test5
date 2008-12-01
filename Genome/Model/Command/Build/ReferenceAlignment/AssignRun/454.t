#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More skip_all => 'This simple command still takes 10 minutes or more because of the db query';
#use Test::More tests => 7;

BEGIN {
        use_ok('Genome::Model::Command::Build::ReferenceAlignment::AssignRun::454');
}

my $subject_name = 'H_GP-0364t';
my $subject_type = 'genomic dna';
my $bogus_id = 0;
my $data_directory = File::Temp::tempdir(CLEANUP => 1);

my $pp = Genome::ProcessingProfile::ReferenceAlignment->create_mock(
                                                                    id => --$bogus_id,
                                                                );
isa_ok($pp,'Genome::ProcessingProfile::ReferenceAlignment');


my $model = Genome::Model::ReferenceAlignment->create_mock(
                                                           id => --$bogus_id,
                                                           genome_model_id => $bogus_id,
                                                           processing_profile_id => $pp->id,
                                                           subject_type => $subject_type,
                                                           subject_name => $subject_name,
                                                           last_complete_build_id => undef,
                                                           name => '454_ref_align_mock_test',
                                                           data_directory => $data_directory,
                                                           sequencing_platform => '454',
                                                       );
isa_ok($model,'Genome::Model::ReferenceAlignment');
$model->set_always('lock_resource',1);

my $read_set = Genome::RunChunk::454->create_mock(
                                                  id => --$bogus_id,
                                                  genome_model_run_id => $bogus_id,
                                                  sequencing_platform => '454',
                                                  sample_name => 'Pooled DNA 2008-10-15 pcr product Set 2',
                                                  full_path => $model->data_directory,
                                              );
isa_ok($read_set,'Genome::RunChunk::454');

my $read_set_link = Genome::Model::ReadSet->create_mock(
                                                        id => $read_set->id,
                                                        model_id => $model->id,
                                                        read_set_id => $read_set->id,
                                                        sequencing_platform => $read_set->sequencing_platform,
                                                        sample_name => $read_set->sample_name,
                                                        full_path => $model->data_directory,
                                                    );
isa_ok($read_set_link,'Genome::Model::ReadSet');

my $assign_run = Genome::Model::Command::Build::ReferenceAlignment::AssignRun::454->create(
                                                                                           model => $model,
                                                                                           read_set => $read_set
                                                                                       );
isa_ok($assign_run,'Genome::Model::Command::Build::ReferenceAlignment::AssignRun::454');

ok($assign_run->execute,'execute command '. $assign_run->command_name);
ok($assign_run->verify_successful_completion,'verify_successful_completion for '. $assign_run->command_name);

exit;
