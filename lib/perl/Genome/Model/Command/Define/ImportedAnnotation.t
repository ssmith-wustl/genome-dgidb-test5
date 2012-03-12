#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1; #Give me the infos
};

use Test::More tests => 12;

use above 'Genome';

use_ok('Genome::Model::Command::Define::ImportedAnnotation');

my $reference_sequence_build;
my $version;
my $build_name;
my $species = 'human';
my $processing_profile = Genome::ProcessingProfile->get(2070042); #imported-annotation.ensembl
my $model_name = 'NCBI-human.ensembl';

#This should fail because the build already exists
$build_name = 'NCBI-human.ensembl/58_37c';
$version = '58_37c';
$reference_sequence_build = Genome::Model::Build->get(102671028); #GRCh37-lite-build37

my $existing_cmd = Genome::Model::Command::Define::ImportedAnnotation->create(
            species_name => $species,
            version => $version,
            reference_sequence_build => $reference_sequence_build,
            build_name => $build_name,
            processing_profile => $processing_profile,
            model_name => $model_name,
          );
ok($existing_cmd, 'Successfully created ImportedAnnotation definition command');
ok(!$existing_cmd->execute, 'Failed to create a build for existing 58_37c');

#This should succeed nicely
$build_name = 'NCBI-human.ensemb/64_37i';
$version = '64_37i';
$reference_sequence_build = Genome::Model::Build->get(106942997); #GRCh37-lite-build37

my $good_cmd = Genome::Model::Command::Define::ImportedAnnotation->create(
            species_name => $species,
            version => $version,
            reference_sequence_build => $reference_sequence_build,
            build_name => $build_name,
            processing_profile => $processing_profile,
            model_name => $model_name,
          );
ok($good_cmd, 'Successfully created ImportedAnnotation definition command');
ok($good_cmd->execute, 'Successfully defined ImportedAnnotation build');
ok($good_cmd->result_model_id == 2772828715, 'Used existing NCBI-human.ensembl model');
ok($good_cmd->result_build_id, 'Returned a build id');

#This should succeed, but it will have to create a new model in the process
$processing_profile = Genome::ProcessingProfile::ImportedAnnotation->create(
                                name => 'test-processing-profile',
                                annotation_source => 'test-source',
                                interpro_version => '4.5',
                              );
$build_name = 'test_name.test-source/01_37a';
$version = '01_37a';

my $cmd = Genome::Model::Command::Define::ImportedAnnotation->create(
            species_name => $species,
            version => $version,
            reference_sequence_build => $reference_sequence_build,
            build_name => $build_name,
            processing_profile => $processing_profile,
          );
ok($cmd, 'Successfully created ImportedAnnotation definition command');
# ok($cmd->execute, 'Successfully defined ImportedAnnotation build');
# ok($cmd->result_model_id < 0, 'Created new imported annotation model');
# ok($cmd->result_build_id < 0, 'Created a new imported annotation build');

#try a mouse model
$build_name = 'NCBI-mouse.ensembl/64_37q';
$version = '64_37q';
$reference_sequence_build = Genome::Model::Build->get(107494762); #UCSC-mouse-buildmm9
$species = 'mouse';
$model_name = 'NCBI-mouse.ensembl';
$processing_profile = Genome::ProcessingProfile->get(2070042); #imported-annotation.ensembl

my $mouse_cmd = Genome::Model::Command::Define::ImportedAnnotation->create(
            species_name => $species,
            version => $version,
            reference_sequence_build => $reference_sequence_build,
            build_name => $build_name,
            processing_profile => $processing_profile,
            model_name => $model_name,
          );
ok($mouse_cmd, 'Successfully created ImportedAnnotation definition command');
ok($mouse_cmd->execute, 'Successfully defined ImportedAnnotation build');
ok($mouse_cmd->result_model_id == 2802635661, 'Used existing NCBI-mouse.ensembl model');
ok($mouse_cmd->result_build_id, 'Returned a build id');
