#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 26;

BEGIN {
    use_ok('Genome::Model::Command::Build::ScheduleStage');
}

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $bogus_id = 0;

my $pp = Genome::ProcessingProfile->create_mock(id => --$bogus_id);
isa_ok($pp,'Genome::ProcessingProfile');
my $model = &get_model($pp);
$model->set_always('build_subclass_name','');

my $no_id = Genome::Model::Command::Build::ScheduleStage->create(
                                                                 model_id => $model->id,
                                                                 stage_name => 'stage1',
                                                             );
isa_ok($no_id->build,'Genome::Model::Command::Build');

my $good_build = &get_good_build($model);
$model->set_always('current_running_build_id',$good_build->id);
my $pass_id = Genome::Model::Command::Build::ScheduleStage->create(
                                                                   model_id => $model->id,
                                                                   build_id => $good_build->id,
                                                                   stage_name => 'stage1',
                                                               );
is($pass_id->build_id,$good_build->id,'passed in the build_id as param');

my $crb_id = Genome::Model::Command::Build::ScheduleStage->create(
                                                                  model_id => $model->id,
                                                                  stage_name => 'stage1',
                                                              );
is($crb_id->build_id,$good_build->id,'the models current_running_build_id is the build');

my $bad_id;
eval {
    $bad_id = Genome::Model::Command::Build::ScheduleStage->create(
                                                                   model_id => $model->id,
                                                                   build_id => --$bogus_id,
                                                                   stage_name => 'stage1',
                                                               );
};
ok(!$bad_id,'Failed to create command with bad build id');

my $stage_not_found_error = Genome::Model::Command::Build::ScheduleStage->create(
                                                                                 model_id => $model->id,
                                                                                 stage_name => 'test_stage',
                                                                             );
isa_ok($stage_not_found_error,'Genome::Model::Command::Build::ScheduleStage');
ok(!$stage_not_found_error->execute,'execute failed with bogus test stage name');


my $stage1 = Genome::Model::Command::Build::ScheduleStage->create(
                                                                   model_id => $model->id,
                                                                   stage_name => 'stage1',
                                                                   auto_execute => 0,
                                                               );
isa_ok($stage1,'Genome::Model::Command::Build::ScheduleStage');
ok($stage1->execute(),'execute command '. $stage1->command_name);
my $stage2 = Genome::Model::Command::Build::ScheduleStage->create(
                                                                  model_id => $model->id,
                                                                  stage_name => 'stage2',
                                                                  auto_execute => 0,
                                                              );
isa_ok($stage2,'Genome::Model::Command::Build::ScheduleStage');
ok($stage2->execute(),'execute command '. $stage2->command_name);


## Test when events already exist for the stage
my $model_with_events = &get_model($pp);
my $build_with_events = &get_build_with_events($model_with_events);

$model_with_events->set_always('current_running_build_id',$build_with_events->id);
my $stage_with_events = Genome::Model::Command::Build::ScheduleStage->create(
                                                                             model_id => $model_with_events->id,
                                                                             stage_name => 'stage1',
                                                                             auto_execute => 0,
                                                                         );
isa_ok($stage_with_events,'Genome::Model::Command::Build::ScheduleStage');
ok(!$stage_with_events->execute,'stage already has events');

## Test when the prior stage will not verify_successful_completion
my $model_no_verify = &get_model($pp);
my $build_no_verify = &get_build_no_verify($model_no_verify);
$model_no_verify->set_always('current_running_build_id',$build_no_verify->id);
my $stage_no_verify = Genome::Model::Command::Build::ScheduleStage->create(
                                                                           model_id => $model_no_verify->id,
                                                                           stage_name => 'stage2',
                                                                           auto_execute => 0,
                                                                       );
isa_ok($stage_no_verify,'Genome::Model::Command::Build::ScheduleStage');
ok(!$stage_no_verify->execute,'failed to execute schedule-stage since prior did not verify');


## Test when scheduling the stage goes wrong
my $bad_model = &get_model($pp);
my $bad_build = &get_bad_build($model_no_verify);
$bad_model->set_always('current_running_build_id',$bad_build->id);
my $bad_stage = Genome::Model::Command::Build::ScheduleStage->create(
                                                                     model_id => $bad_model->id,
                                                                     stage_name => 'stage2',
                                                                     auto_execute => 0,
                                                                 );
isa_ok($bad_stage,'Genome::Model::Command::Build::ScheduleStage');
ok(!$bad_stage->execute,'failed to execute schedule-stage since the stage would not schedule');


exit;

sub get_good_build {
    my $model = shift;
    my $build = Genome::Model::Command::Build->create_mock(
                                                           id => --$bogus_id,
                                                           build_id => $bogus_id,
                                                           genome_model_event_id => $bogus_id,
                                                           model_id => $model->id,
                                                           event_type => 'genome model build',
                                                       );
    isa_ok($build,'Genome::Model::Command::Build');
    my @stages = qw/stage1 stage2 stage3 verify_successful_completion/;
    $build->set_list('stages',@stages);
    $build->mock('events_for_stage',sub { return; });
    $build->set_always('_schedule_stage',1);
    $build->set_always('verify_successful_completion_for_stage',1);
    return $build;
}

sub get_bad_build {
    my $model = shift;
    my $build = Genome::Model::Command::Build->create_mock(
                                                           id => --$bogus_id,
                                                           build_id => $bogus_id,
                                                           genome_model_event_id => $bogus_id,
                                                           model_id => $model->id,
                                                           event_type => 'genome model build',
                                                       );
    isa_ok($build,'Genome::Model::Command::Build');
    my @stages = qw/stage1 stage2 stage3 verify_successful_completion/;
    $build->set_list('stages',@stages);
    $build->mock('events_for_stage',sub { return; });
    $build->set_always('verify_successful_completion_for_stage',1);
    $build->mock('_schedule_stage',sub {return; });
    my @classes = qw/class1 class2 class3/;
    $build->set_list('classes_for_stage',@classes);
    return $build;
}

sub get_build_no_verify {
    my $model = shift;
    my $build = Genome::Model::Command::Build->create_mock(
                                                           id => --$bogus_id,
                                                           build_id => $bogus_id,
                                                           genome_model_event_id => $bogus_id,
                                                           model_id => $model->id,
                                                           event_type => 'genome model build',
                                                       );
    isa_ok($build,'Genome::Model::Command::Build');
    my @stages = qw/stage1 stage2 stage3 verify_successful_completion/;
    $build->set_list('stages',@stages);
    $build->mock('events_for_stage',sub { return; });
    $build->set_always('verify_successful_completion_for_stage',0);
    return $build;
}

sub get_build_with_events {
    my $model = shift;
    my $build = Genome::Model::Command::Build->create_mock(
                                                           id => --$bogus_id,
                                                           build_id => $bogus_id,
                                                           genome_model_event_id => $bogus_id,
                                                           model_id => $model->id,
                                                           event_type => 'genome model build',
                                                       );
    isa_ok($build,'Genome::Model::Command::Build');
    my @stages = qw/stage1 stage2 stage3 verify_successful_completion/;
    $build->set_list('stages',@stages);
    my @events = qw/event1 event2 event3/;
    $build->set_list('events_for_stage',@events);
    return $build;
}

sub get_model {
    my $pp = shift;
    my $model = Genome::Model->create_mock(
                                           id => --$bogus_id,
                                           genome_model_id => $bogus_id,
                                           name => 'test_model_name',
                                           subject_name => 'test_subject_name',
                                           subject_type => 'test_subject_type',
                                           processing_profile_id => $pp->id,
                                           data_directory => $tmp_dir,
                                       );
    isa_ok($model,'Genome::Model');
    return $model;
}
