#!/gsc/bin/perl

# FIXME Tests to cover:
# Allocation - all allocation in builds are not tested
# Reports - limited report testing

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More; 
require Genome::Model::DeNovoAssembly::Test;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok('Genome::Model::Build') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_velvet;
ok($model, 'Create de novo model');
my ($ida) = $model->instrument_data_assignments;
ok(!$ida->first_build_id, 'first build id is undef');
my @model_inst_data = $model->instrument_data;
ok(@model_inst_data, 'Added instrument data to model');
my @model_inputs = $model->inputs;
is(scalar(@model_inputs), 2, 'Correct number of model inputs');
is($model->center_name, 'WUGC', 'model center name');

#< Real create >#
my $build = $model->create_build(
    model_id => $model->id,
);
ok($build, 'Created build');
isa_ok($build, 'Genome::Model::Build');
is(ref($build), $build->subclass_name, 'subclass_name is correctly filled in');
is($build->data_directory,$model->data_directory.'/build'. $build->id, 'build directory resolved');
is($build->model->id, $model->id, 'indirect model accessor');

#< Inputs >#
my @build_inputs = $build->inputs;
is(scalar(@build_inputs), 2, 'Correct number of build inputs');
my @build_inst_data = $build->instrument_data;
is_deeply(\@build_inst_data, \@model_inst_data, 'Build instrument data');
is($build->instrument_data_count, 1, 'Instrument data count');
is($ida->first_build_id, $build->id, 'first build id is set');
is($build->center_name, 'WUGC', 'build center name');
#print Data::Dumper::Dumper({bin=>\@build_inputs,bid=>\@build_inst_data,min=>\@model_inputs,mid=>\@model_inst_data,});

#< ACTIONS >#
# SCHEDULE
# try to init, succ and fail an unscheduled build
ok(!$build->initialize, 'Failed to initialize an unscheduled build');
ok(!$build->fail, 'Failed to fail an unscheduled build');
ok(!$build->success, 'Failed to success an unscheduled build');
# schedule - check events
$DB::single = 1;
my ($workflow) = $build->_initialize_workflow('inline');
ok($workflow, 'initialized a workflow');

my $build_event = $build->build_event;
ok($build_event, 'Got build event');
is($build_event->event_status, 'Scheduled', 'Build status is Scheduled');
is($build->status, 'Scheduled', 'Build status is Scheduled');
my @events = Genome::Model::Event->get(
    id => { operator => 'ne', value => $build_event->id },
    model_id => $model->id,
    build_id => $build->id,
    event_status => 'Scheduled',
);
is(scalar(@events), 4, 'Scheduled 4 events');
# try to schedule again - should fail
my $result = eval { $build->start };
ok(!$result, 'Failed to schedule build again');

# Check to addressees for reports
my $user = $build_event->user_name;
my $to = $build->_get_to_addressees_for_report_generator_class('Genome::Model::Report::BuildInitialized');
is($to, $user.'@genome.wustl.edu', 'initialized report goes to user');
$to = $build->_get_to_addressees_for_report_generator_class('Genome::Model::Report::BuildSucceeded');
is($to, $user.'@genome.wustl.edu', 'succeeded report goes to user');
$to = $build->_get_to_addressees_for_report_generator_class('Genome::Model::Report::BuildFailed');
is($to, $user.'@genome.wustl.edu', 'failed report goes to user');

$build_event->user_name('apipe-builder'); # changing to apipe-builder
$to = $build->_get_to_addressees_for_report_generator_class('Genome::Model::Report::BuildInitialized');
ok(!$to, 'initialized report for apipe-builder does not get sent');
$to = $build->_get_to_addressees_for_report_generator_class('Genome::Model::Report::BuildSucceeded');
ok(!$to, 'succeeded report for apipe-builder does not get sent');
$to = $build->_get_to_addressees_for_report_generator_class('Genome::Model::Report::BuildFailed');
is($to, 'apipe-builder@genome.wustl.edu', 'failed report for apipe-builder gets sent');

# do not send the report
my $gss_report = *Genome::Model::Build::generate_send_and_save_report;
no warnings 'redefine';
*Genome::Model::Build::generate_send_and_save_report = sub{ return 1; };
use warnings;

# INITIALIZE
ok($build->initialize, 'Initialize');
is($build->status, 'Running', 'Status is Running');
is($model->current_running_build_id, $build->id, 'Current running build id set to build id in initialize');

# FAIL
ok($build->fail([]), 'Fail');
is($build->status, 'Failed', 'Status is Failed');

# SUCCESS
isnt($model->_last_complete_build_id, $build->id, 'Model last complete build is not this build\'s id');
ok($build->success, 'Success');
is($build->status, 'Succeeded', 'Status is Succeeded');
ok(!$model->current_running_build_id, 'Current running build id set to undef in success');
is($model->_last_complete_build_id, $build->id, 'Model last complete build is set to this build\'s id in success');

# ABANDON
ok($build->abandon, 'Abandon');
is($build->status, 'Abandoned', 'Status is Abandoned');
isnt($model->last_complete_build_id, $build->id, 'Model last complete build is not this build\'s id in abandon');
is(grep({$_->event_status eq 'Abandoned'} @events), 4, 'Abandoned all events');
# try to init, fail and succeed a abandoned build
ok(!$build->initialize, 'Failed to initialize an abandoned build');
ok(!$build->fail, 'Failed to fail an abandoned build');
ok(!$build->success, 'Failed to success an abandoned build');

no warnings 'redefine';
*Genome::Model::Build::generate_send_and_save_report = $gss_report;
use warnings;

#< DELETE >#
# set build events status to not abandoned
for my $e ( @events ) { $e->event_status('Running'); }
ok($build->delete, 'Deleted build');

#Test the Build Success Callback
#(Ideally would test if commit() triggers the callback automatically, but does not fire when no_commit(1).)
my $m1 = Genome::Model::Test->create_basic_mock_model(type_name => 'tester');
my $m2 = Genome::Model::Test->create_basic_mock_model(type_name => 'tester');
my $mock_build = Genome::Model::Build->create(model_id => $m1->id); 
$m1->mock('create_build', sub { return $mock_build });
$m1->add_to_model(to_model => $m2);
$m2->auto_build_alignments(1);
my $b1 = $m1->create_build(model_id => $m1->id);
$b1->_initialize_workflow('inline');
$b1->success();  #TODO Check that callback is at least registered successfully

ok($b1->model->processing_profile->_build_success_callback($b1), 'callback executed successfully');
ok($m2->build_requested, 'callback triggered build_requested flag in to_model');

done_testing();
exit;

