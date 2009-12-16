#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use File::Temp;
use File::Path;
use File::Basename;
use Test::MockObject;
use Test::More tests => 104;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    use_ok('Genome::Model::Event');
}

my $run_lsf_test = 0;
my $wait = 8;
my $bogus_id = 0;

my $test_data_directory = File::Temp::tempdir(CLEANUP => 1);
my $pp = Genome::ProcessingProfile->create_mock(id => --$bogus_id);
my $model = Genome::Model->create_mock(
                                       genome_model_id => --$bogus_id,
                                       id => $bogus_id,
                                       name => 'test_model_name',
                                       subject_name => 'test_subject_name',
                                       subject_type => 'test_subject_type',
                                       processing_profile_id => $pp->id,
                                       data_directory => $test_data_directory,
                                   );
$model->set_always('latest_build_directory', $test_data_directory);
$model->set_list('instrument_data_assignments',Genome::Model::InstrumentDataAssignment->get(
                                                                                            instrument_data_id => 2499312867,
                                                                                            model_id => 2721044485
                                                                                        ));

my $build = Genome::Model::Build->create_mock(
                                              id => --$bogus_id,
                                              build_id => $bogus_id,
                                              model_id => $model->id,
                                              data_directory => $test_data_directory .'/build'. $bogus_id,
                                          );
my $build_event = Genome::Model::Event->create_mock(
                                                         id => --$bogus_id,
                                                         genome_model_event_id => $bogus_id,
                                                         build_id => $build->id,
                                                         model_id => $model->id,
                                                         event_type => 'genome model build',
                                                         event_status => 'Succeeded',
                                                   );
$build_event->set_always('data_directory',$build->data_directory);

my $new_build = Genome::Model::Build->create_mock(
                                                  id => --$bogus_id,
                                                  build_id => $bogus_id,
                                                  model_id => $model->id,
                                                  data_directory => $test_data_directory .'/build'. $bogus_id,
                                              );

my %params = (
              event_type => $build_event->event_type,
              model_id => $model->id,
              user_name => $ENV{USER},
              parent_event_id => $build_event->genome_model_event_id,
              build_id => $new_build->id,
              prior_event_id => $build_event->genome_model_event_id,
              lsf_job_id => 'test_lsf_job_id',
              retry_count => 'test_retry_count',
              status_detail => 'test_status_detail',
          );

my $event = Genome::Model::Event->create(%params);
isa_ok($event, 'Genome::Model::Event');
ok($event->bsub_rusage(), 'has bsub_rusage method');
like($event->bsub_rusage(), qr/LINUX64/, 'requests 64-bit type');
like($event->bsub_rusage(), qr/span\[hosts\=1\]/, 'requests 1 host');
unlike($event->bsub_rusage(), qr/xeon/i, 'does not request xeon model');

#< Logging >#
my $base_log_dir = $new_build->data_directory.'/logs/';
is($event->log_directory, $base_log_dir, 'log directory');
ok($event->create_log_directory, 'created log directory');
ok(-d $base_log_dir, 'log directory exists');
is($event->error_log_file, $base_log_dir.'/'.$event->id.'.err', 'error log file');
is($event->output_log_file, $base_log_dir.'/'.$event->id.'.out', 'output log file');
#<>#

$event->dump_error_messages(0);
$event->dump_warning_messages(0);
$event->dump_status_messages(0);
$event->queue_error_messages(1);
$event->queue_warning_messages(1);
$event->queue_status_messages(1);

my $event_model = $event->model;
isa_ok($event_model,'Genome::Model');

# test each property set in the create with %params
for my $property_name (keys %params) {
    is($event->$property_name,$params{$property_name},$property_name .' event accessor');
}
is($event->build_id,$new_build->id,'build_id event accessor');

# test the existence and id of parent_event
my $parent_event = $event->parent_event;
isa_ok($parent_event,'Genome::Model::Event');
is($parent_event->genome_model_event_id,$build_event->genome_model_event_id,'parent event id matches expected');

# test the existence and id of prior_event
my $prior_event = $event->prior_event;
isa_ok($prior_event,'Genome::Model::Event');
is($prior_event->genome_model_event_id,$build_event->genome_model_event_id,'prior event id matches expected');
$prior_event->event_status('Succeeded');
ok($event->verify_prior_event,'prior event verified');
$prior_event->event_status('Scheduled');
ok(!$event->verify_prior_event,'prior event not verified');
ok(scalar(grep { $_ =~ /Prior event .* is not Succeeded/ } $event->error_messages),'prior event not verified error message');

ok($event->should_calculate,'should calculate metrics for event status'. $event->event_status);

is($event->build_directory,$new_build->data_directory,'data directory from parent event');

for my $hang_off qw(input output metric) {
    my %hang_off_params =  (
                            name => 'test_'. $hang_off .'_name',
                            value => 'test_'. $hang_off .'_value',
                        );
    my $add_method_name = 'add_'. $hang_off;
    $event->$add_method_name(%hang_off_params);
    my $object_method = $hang_off .'s';
    my @objects = $event->$object_method;
    is(scalar(@objects),1,'got one '. $hang_off .' object for event');
    my $object = $objects[0];
    my $class = ucfirst($hang_off);
    isa_ok($object,'Genome::Model::Event::'. $class);
    for my $hang_off_property (keys %hang_off_params) {
        is($object->$hang_off_property,$hang_off_params{$hang_off_property}, $hang_off_property .' event '. $hang_off .' accessor');
    }
}
my @metric_names = $event->metric_names;
is(scalar(@metric_names),1,'got one metric_name for event');
is($metric_names[0],'test_metric_name','expected metric name found');
is($event->get_metric_value($metric_names[0]),'test_metric_value','accessor to get metric value given name');

my @objects = $event->get_all_objects;
is(scalar(@objects),3,'Found 3 hang off objects');
ok(scalar( grep { $_->class =~ /^Genome::Model::Event::Input$/ } @objects),'Found one input');
ok(scalar( grep { $_->class =~ /^Genome::Model::Event::Output$/ } @objects),'Found one output');
ok(scalar( grep { $_->class =~ /^Genome::Model::Event::Metric$/ } @objects),'Found one metric');

ok($event->revert,'revert event');

is(scalar( grep { $_ =~ /^deleting .* with id .*/ } $event->warning_messages ), 3, 'found 3 error messages about deleting objects');

@objects = $event->get_all_objects;
ok(!scalar(@objects),'no objects found after revert');

my $yaml_string = $event->yaml_string;
my $yaml_header = '--- \!\!perl/hash:'. $event->class;
like($yaml_string,qr/$yaml_header/,'found expected yaml string');

my $event_tmp_dir = $event->base_temp_directory;
ok($event_tmp_dir, 'got a base temp directory '. $event_tmp_dir);
ok(-d $event_tmp_dir, $event_tmp_dir .' is a directory');

my $tmp_file_path = $event->create_temp_file_path;
ok($tmp_file_path, 'got a tmp file path '. $tmp_file_path);
ok(!-e $tmp_file_path, $tmp_file_path .' does not exist yet');

my $dirname = File::Basename::dirname($tmp_file_path);
my $basename = File::Basename::basename($tmp_file_path);
is($dirname,$event_tmp_dir,'event temp dir correct');
$DB::single=1;
ok($event->create_temp_directory($basename),'create tmp file path dir '. $tmp_file_path);
ok(scalar(grep { $_ =~ /Created directory\: $tmp_file_path/ } $event->status_messages),'status message found when directory created');

my $return_value;
eval{
    $return_value = $event->create_temp_file_path($basename);
};
ok(!defined($return_value),'failed to create existing tmp file path');
isa_ok($event->create_temp_file,'GLOB');

ok($event->check_for_existence($tmp_file_path),'temp file exists');
ok(scalar(grep { $_ =~ /existence check passed: $tmp_file_path/ } $event->status_messages),'status message found for existence');

ok(rmtree($tmp_file_path),'remove directory '. $tmp_file_path);
ok(!$event->check_for_existence($tmp_file_path),'temp file does not exist');
ok($event->create_temp_directory($basename),'created directory again');
is(scalar(grep { $_ =~ /Created directory\: $tmp_file_path/ } $event->status_messages),2,'two status messages found for directory creation');
ok($event->check_for_existence($tmp_file_path,1),'temp file exists');
is(scalar(grep { $_ =~ /existence check passed: $tmp_file_path/ } $event->status_messages),2,'two status messages found for existence');
ok(rmtree($tmp_file_path),'remove directory '. $tmp_file_path);

my $create_file_return;
eval {
    $create_file_return = $event->create_file('test_output_name');
};
ok(!$create_file_return,'failed to create file without path');
my $create_file_test_fh = $event->create_file('test_output_name',$tmp_file_path);
isa_ok($create_file_test_fh,'GLOB');

eval {
    $create_file_return = $event->create_file('test_output_name','/tmp/test');
};
ok(!$create_file_return,'failed to create file with same output name but different path');
eval {
    $create_file_return = $event->create_file('test_output_name',$tmp_file_path);
};
ok(!$create_file_return,'failed to create file with same output name with same path');

ok($event->schedule,'schedule this event');
is($event->event_status,'Scheduled','event status is now Scheduled');
ok($event->date_scheduled,'date_scheduled is set');
ok(!defined($event->date_completed),'date_completed is undef');

is($event->desc,$event->id .' ('. $event->event_type .')','found expected event description');
ok($event->is_reschedulable,'the event is reschedulable');
is($event->max_retries,2,'the max retries is set to 2');
ok(!$event->metrics_for_class,'metrics for class not implemented in abstract base class');

ok(!$event->lsf_job_state,'no lsf_job_stata found');

ok($event->abandon,'event abandoned');

ok($event->delete,'event deleted');

SKIP: {
    skip 'probably not a good idea to create lsf jobs all the time', 17 unless $run_lsf_test;
    &test_lsf();
}

exit;

sub test_lsf {
    my $bogus_id = 0;
    my $pp = Genome::ProcessingProfile->create_mock(
                                                    id => --$bogus_id,
                                                );

    my $model = Genome::Model->create_mock(
                                           genome_model_id => --$bogus_id,
                                           id => $bogus_id,
                                           processing_profile_id => $pp->id,
                                           last_complete_build_id => undef,
                                           subject_type => 'mock_subject_type',
                                           subject_name => 'mock_subject_name',
                                           name => 'mock_model',
                                       );

    my $lsf_event = Genome::Model::Event->create_mock(
                                                  genome_model_event_id => --$bogus_id,
                                                  id => $bogus_id,
                                                  model_id => $model->id,
                                                  event_type => 'genome model mock-event-type',
                                              );
    isa_ok($lsf_event,'Genome::Model::Event');
    $lsf_event->mock('lsf_job_state',\&Genome::Model::Event::lsf_job_state);
    $lsf_event->mock('lsf_dependency_condition',\&Genome::Model::Event::lsf_dependency_condition);
    $lsf_event->mock('lsf_pending_reasons',\&Genome::Model::Event::lsf_pending_reasons);

    my $exit_lsf_job_id = &do_bsub(0);
    my $dependency_condition = "done($exit_lsf_job_id)";
    my $done_lsf_job_id = &do_bsub(1,"-w '$dependency_condition'");

    # Test initial pending state of done job with dependency
    $lsf_event->lsf_job_id($done_lsf_job_id);
    is($lsf_event->lsf_job_state,'PSUSP','PSUSP job state for '. $lsf_event->lsf_job_id);

    # resume the job with dependency
    &do_bresume($done_lsf_job_id);
    is($lsf_event->lsf_job_state,'PEND','PEND job state for '. $lsf_event->lsf_job_id);
    is($lsf_event->lsf_dependency_condition,$dependency_condition,'found dependency condition for '. $lsf_event->lsf_job_id);
    my @valid_pending_reasons = $lsf_event->lsf_pending_reasons;
    ok(scalar( grep { /Job dependency condition not satisfied;/ } @valid_pending_reasons),'valid dependency condition for '. $lsf_event->lsf_job_id);

    # switch to the job expected to exit
    $lsf_event->lsf_job_id($exit_lsf_job_id);
    is($lsf_event->lsf_job_state,'PSUSP','PSUSP job state for '. $lsf_event->lsf_job_id);
    &do_bresume($exit_lsf_job_id);
    while ($lsf_event->lsf_job_state ne 'EXIT') {
        sleep($wait);
    }
    is($lsf_event->lsf_job_state,'EXIT','EXIT job state for '. $lsf_event->lsf_job_id);

    sleep($wait);
    # switch back to the job with now invalid dependency
    $lsf_event->lsf_job_id($done_lsf_job_id);
    is($lsf_event->lsf_job_state,'PEND','PEND job state for '. $lsf_event->lsf_job_id);
    is($lsf_event->lsf_dependency_condition,$dependency_condition,'found dependency condition for '. $lsf_event->lsf_job_id);

    my @invalid_pending_reasons = $lsf_event->lsf_pending_reasons;
    ok(scalar( grep { /Dependency condition invalid or never satisfied;/ } @invalid_pending_reasons),'invalid dependency condition for '. $lsf_event->lsf_job_id);

    &do_bkill($done_lsf_job_id);
}


sub do_bsub {
    my $return_value = shift;
    my $bsub_args = shift;
    if ($return_value != 0 && $return_value != 1) {
        die;
    }
    my $bsub_cmd = 'bsub -q short -H ';
    if ($bsub_args) {
        $bsub_cmd .= $bsub_args;
    }
    my $perl = "perl -e 'return $return_value;'";
    my $bsub_output = `$bsub_cmd $perl`;
    my $retval = $? >> 8;
    ok(!$retval,'backtick call to bsub returned zero');
    like($bsub_output,qr/Job <\d+>/,'bsub job id found');
    $bsub_output =~ m/Job <(\d+)>/;
    sleep($wait);
    return $1;
}

sub do_bresume {
    my $lsf_job_id = shift;
    my $bresume_rv = system("bresume $lsf_job_id");
    ok(!$bresume_rv,'resume lsf job '. $lsf_job_id);
    sleep($wait);
}

sub do_bkill {
    my $lsf_job_id = shift;
    my $bkill_rv = system("bkill $lsf_job_id");
    ok(!$bkill_rv,'bkill lsf job '. $lsf_job_id);
    sleep($wait);
}

1;
