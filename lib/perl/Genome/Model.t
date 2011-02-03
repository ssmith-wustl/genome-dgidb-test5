#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

require File::Temp;
use Test::More;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok('Genome::Model') or die;

# SUB CLASSES TO TEST GENOME::MODEL
class Genome::ProcessingProfile::Tester {
    is => 'Genome::ProcessingProfile',
};
sub Genome::ProcessingProfile::Tester::sequencing_platform { return 'solexa'; };

class Genome::Model::Tester {
    is => 'Genome::Model',
};

class Genome::Model::Build::Tester {
    is => 'Genome::Model::Build',
};

# PP
my $pp = Genome::ProcessingProfile->create(
    name => 'Tester PP',
    type_name => 'tester',
);
ok($pp, 'create processing profile') or die;

# SUBJECT 
my $sample = Genome::Sample->create(
    id => -654321,
    name => 'TEST-00',
);
ok($sample, 'create sample') or die;
my $library = Genome::Library->create(
    name => $sample->name.'-testlib',
    sample_id => $sample->id,
);
ok($library, 'create library');

# DATA DIR
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'create tmpdir');

# CREATE
# fail - no pp
my $model_fail = eval {
    Genome::Model->create(
        name => 'Tester Model',
        subject_id => $sample->id,
        subject_class_name => $sample->class,
        data_directory => $tmpdir,
    );
};
ok(!$model_fail, 'failed to create model w/o pp');

# fail - no invalid pp
$model_fail = eval {
    Genome::Model->create(
        name => 'Tester Model',
        processing_profile_id => -999999,
        subject_id => $sample->id,
        subject_class_name => $sample->class,
        data_directory => $tmpdir,
    );
};
ok(!$model_fail, 'failed to create model w/ invalid pp');

# fail - no subject
$model_fail = eval{ 
    Genome::Model->create(
        name => 'Tester Model',
        processing_profile => $pp,
        data_directory => $tmpdir,
    );
};
ok(!$model_fail, 'failed to create model w/o subject');

# fail - invalid subject
$model_fail = eval{ 
    Genome::Model->create(
        name => 'Tester Model',
        processing_profile => $pp,
        subject_id => -999999,
        subject_class_name => $sample->class,
        data_directory => $tmpdir,
    );
};
ok(!$model_fail, 'failed to create model w/ invalid subject');

# success
my $model = Genome::Model->create(
    name => 'Tester Model',
    processing_profile => $pp,
    subject_id => $sample->id,
    subject_class_name => $sample->class,
    data_directory => $tmpdir,
);
ok($model, 'create model');

# recreate fails
$model_fail = eval {
    Genome::Model->create(
        name => 'Tester Model',
        processing_profile => $pp,
        subject_id => $sample->id,
        subject_class_name => $sample->class,
        data_directory => $tmpdir,
    );
};
ok(!$model_fail, 'failed to recreate model');

# DATA DIR
is($model->data_directory, $tmpdir, "data_directory == tmpdir");
ok($model->resolve_data_directory, "resolve_data_directory == tmpdir");

# INSTRUMENT DATA
my @instrument_data;
for my $i (1..2) {
    unshift @instrument_data, Genome::InstrumentData::Solexa->create( # keep in reverse order
        sequencing_platform => 'solexa',
        library_id => $library->id,
        read_length => 100,
        clusters => 100,
    );
}
is(@instrument_data, 2, 'create instrument data');

# compatible
my @compatible_id = $model->compatible_instrument_data;
is_deeply(
    \@compatible_id,
    \@instrument_data,
    "compatible_instrument_data"
);

# available/unassigned
can_ok($model, 'unassigned_instrument_data'); # same as available
my @available_id = $model->available_instrument_data;
is_deeply(
    \@available_id,
    \@compatible_id,
    "available_instrument_data"
);

# ASSIGN INST DATA
my @idas;
for my $instrument_data ( @instrument_data ) {
    push @idas, Genome::Model::InstrumentDataAssignment->create(
        model => $model,
        instrument_data => $instrument_data,
    );
}
is(@idas, 2, 'create ida');
my @model_instrument_data = $model->instrument_data; # check vai ida
is_deeply(\@model_instrument_data, \@instrument_data, 'model instrument data via ida');
my @model_inst_data = $model->inst_data; # check via inputs
is_deeply(\@model_inst_data, \@instrument_data, 'model instrument data via inputs');

# BUILDS
# create these in reverse order because of negative ids
my @builds;
for my $i (1..2) {
    unshift @builds, Genome::Model::Build->create(
        model => $model,
        data_directory => $model->data_directory.'/build'.$i,
    );
    my $event = Genome::Model::Event->create(
        model => $model,
        build => $builds[0],
        event_type => 'genome model build',
        date_scheduled => UR::Time->now,
        date_completed => UR::Time->now,
        user_name => $ENV{USER},
    );
    ok($event, 'create master event');
    my $master_event = $builds[0]->the_master_event;
    is_deeply($master_event, $event, 'got master event from build');
}
is(@builds, 2, 'create builds');
my @model_builds = $model->builds;
is_deeply(\@model_builds, \@builds, 'model builds');

my @built_instrument_data = $model->built_instrument_data;
is_deeply(\@built_instrument_data, \@instrument_data, 'built instruemnt data');

# one succeeded, one running
$builds[0]->the_master_event->event_status('Succeeded');
is($builds[0]->status, 'Succeeded', 'build 0 is succeeded');
$builds[1]->the_master_event->event_status('Running');
is($builds[1]->status, 'Running', 'build 1 is running');

my @completed_builds = $model->completed_builds;
is_deeply(\@completed_builds, [$builds[0]], 'completed builds');
is_deeply([$model->last_complete_build], [$builds[0]], 'last completed build');
is($model->last_complete_build_id, $builds[0]->id, 'last completed build id');
is($model->_last_complete_build_id, $builds[0]->id, '_last completed build id');

my @succeed_builds = $model->succeeded_builds;
is_deeply(\@succeed_builds, [$builds[0]], 'succeeded builds');
is_deeply([$model->last_succeeded_build], [$builds[0]], 'last succeeded build');
is($model->last_succeeded_build_id, $builds[0]->id, 'last succeeded build id');

my @running_builds = $model->running_builds;
is_deeply(\@running_builds, [$builds[1]], 'running builds');

# both succeeded
$builds[1]->the_master_event->event_status('Succeeded');
is($builds[1]->status, 'Succeeded', 'build 1 is now succeeded');

@completed_builds = $model->completed_builds;
is_deeply(\@completed_builds, \@builds, 'completed builds');
is_deeply([$model->last_complete_build], [$builds[1]], 'last completed build');
is($model->last_complete_build_id, $builds[1]->id, 'last completed build');
is($model->_last_complete_build_id, $builds[1]->id, '_last completed build id');
@succeed_builds = $model->succeeded_builds;
is_deeply(\@succeed_builds, \@builds, 'succeeded builds');
is_deeply([$model->last_succeeded_build], [$builds[1]], 'last succeeded build');
is($model->last_succeeded_build_id, $builds[1]->id, 'last succeeded build id');

done_testing();
exit;

