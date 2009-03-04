#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 33;

# TODO: Use this for the model creation below...
=cut
use Test::Mock;
# Mock up a processing profile
my $processing_profile = Test::MockObject->new();
$processing_profile->fake_module('Genome::ProcessingProfile');
$processing_profile->set_always('type_name', 'reference alignment');
=cut

use above "Genome";

# TODO: Fix this some how... we should create a model here rather than getting one
=cut
my $model_name = "test_solexa_$ENV{USER}";
my $subject_name = 'H_GV-933124G-skin1-9017g';
my $subject_type = 'sample_name';
my $processing_profile_name = "test_solexa_pp_$ENV{USER}";
my $model = Genome::Model->create();
=cut

my $model = Genome::Model->get(name => 'AML-tumor-new_maq-no_ss_dups');
ok($model, "got a model"); 

isa_ok($model, "Genome::Model::ReferenceAlignment");
ok(my $type_name = $model->_resolve_type_name_for_subclass_name($model->class), "Got the type name from subclass name");
is($type_name, "reference alignment", "Type name returned is correct");

ok(my $model_links_directory = $model->model_links_directory, "Got model links dir ");
ok(-d $model_links_directory, "Model links dir exists: $model_links_directory");

ok(my $alignment_links_directory = $model->alignment_links_directory, "Got alignment links dir");
ok(-d $alignment_links_directory, "alignment links dir exists: $alignment_links_directory");

ok(my $base_model_comparison_directory = $model->base_model_comparison_directory, "Got model comparison dir");
ok(-d $base_model_comparison_directory, "Model comparison dir exists: $base_model_comparison_directory");

ok(my $alignment_directory = $model->alignment_directory, "Got alignment dir");
ok(-d $alignment_directory, "alignment dir exists: $alignment_directory");

ok(my $model_data_directory = $model->model_data_directory, "Got model_data dir");
ok(-d $model_data_directory, "model_data dir exists: $model_data_directory");

ok(my $model_link = $model->model_link, "Got model link");
ok(-d $model_link, "model link exists: $model_link");

ok(my $resolve_data_directory = $model->resolve_data_directory, "Resolved data directory");
ok(my $resolve_reports_directory = $model->resolve_reports_directory, "Resolved reports directory");

ok(my $pretty_print_output = $model->pretty_print_text, "Got a string from pretty_print_text");

ok (my @compatible_instrument_data = $model->compatible_instrument_data, "got compatible_instrument_data");
isa_ok ($compatible_instrument_data[0], "Genome::InstrumentData");

ok (my @available_instrument_data = $model->available_instrument_data, "got available_instrument_data");
isa_ok ($available_instrument_data[0], "Genome::InstrumentData");

ok (my @built_instrument_data = $model->built_instrument_data, "got built_instrument_data");
isa_ok ($built_instrument_data[0], "Genome::InstrumentData");

ok (!$model->unbuilt_instrument_data, "no unbuilt_instrument_data");
my $ida = Genome::Model::InstrumentDataAssignment->get(
                                                       model_id => $model->id,
                                                       instrument_data_id => $built_instrument_data[0]->id,
                                                   );
isa_ok($ida,'Genome::Model::InstrumentDataAssignment');
$ida->first_build_id(undef);

ok (my @unbuilt_instrument_data = $model->unbuilt_instrument_data, "got unbuilt_instrument_data");
isa_ok ($unbuilt_instrument_data[0], "Genome::InstrumentData");


ok (my $available_reports = $model->available_reports, "got available_reports");
foreach my $key(@$available_reports)
{
    diag "REPORT:\t" . $key->name . "\n";
}

SKIP: {
    skip "These are not used and probably will be removed at some point... just have to remove the calls from the tree", 1, if 1;
    $model->lock_directory;
    $model->lock_resource;
    $model->unlock_resource;
}
SKIP: {
    skip "These just take too long because of get_all_objects... implement these once we have a test model without a ton of objects", 1, if 1;
    $model->get_all_objects;
    $model->yaml_string;
}
SKIP: {
    skip "We do not want to test delete unless we are creating a model in the test", 1, if 1;
    $model->delete;
}


