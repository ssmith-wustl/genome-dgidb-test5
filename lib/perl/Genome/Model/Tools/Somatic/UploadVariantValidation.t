#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 10;
use File::Compare;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    use_ok( 'Genome::Model::Tools::Somatic::UploadVariantValidation');
};

my $test_input_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Somatic-UploadVariantValidation/';
my $valid_variant_file    = $test_input_dir . 'valid_variants.in';
my $invalid_variant_file    = $test_input_dir . 'invalid_variants.in';
my $output_file = Genome::Sys->create_temp_file_path;
my $invalid_output_file = Genome::Sys->create_temp_file_path;
my $valid_validation_type = "Illumina";
my $invalid_validation_type = "TACOS";
my $apipe_somatic_test_model = 2853834494; # Bad to hardcode this, but we need a valid model somehow.

my $valid_upload_command = Genome::Model::Tools::Somatic::UploadVariantValidation->create(
    variant_file => $valid_variant_file,
    output_file => $output_file,
    validation_type => $valid_validation_type,
    model_id => $apipe_somatic_test_model,
);

ok($valid_upload_command, 'created UploadVariantValidation object');
ok(!$valid_upload_command->__errors__, "no errors found with creating valid UploadVariantValidation object");
ok($valid_upload_command->execute(), 'executed UploadVariantValidation');
ok(-s $output_file, 'output file exists');

my $invalid_upload_command = Genome::Model::Tools::Somatic::UploadVariantValidation->create(
    variant_file => $valid_variant_file,
    output_file => $output_file,
    validation_type => $invalid_validation_type,
    model_id => $apipe_somatic_test_model,
);

ok($valid_upload_command, 'created UploadVariantValidation object');
ok($invalid_upload_command->__errors__, "errors found with creating invalid UploadVariantValidation object");

my $bad_input_upload_command = Genome::Model::Tools::Somatic::UploadVariantValidation->create(
    variant_file => $invalid_variant_file,
    output_file => $invalid_output_file,
    validation_type => $valid_validation_type,
    model_id => $apipe_somatic_test_model,
);

ok($bad_input_upload_command, 'created UploadVariantValidation object (with a bad input file)');
eval {
    $bad_input_upload_command->execute();
};

ok ($@, "Execute with bad input died with an error");

ok(! -s $invalid_output_file, 'output file for bad input does not exist');




