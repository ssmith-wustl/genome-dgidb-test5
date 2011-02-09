#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Temp;
require Genome::Model::Test;
use Test::More;

# USE
use_ok('Genome::Model::Command::Input::Add') or die;
use_ok('Genome::Model::Command::Input::Remove') or die;

# MODEL
my $model = Genome::Model->get(2857912274); # apipe-test-05-de_novo_velvet_solexa
ok($model, 'got model') or die;

# ADD
note('Add single value');
my $add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'instrument_data',
    'values' => [qw/ 2sep09.934pmaa1 /],
);
ok($add, 'create');
$add->dump_status_messages(1);
my @instrument_data = $model->instrument_data;
is(@instrument_data, 1, 'instrument data is 1');
ok($add->execute, 'execute');
@instrument_data = $model->instrument_data;
is(@instrument_data, 2, 'added instrument data');

note('Fail - add singlular property');
$add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'center_name', 
    'values' => [qw/ none /],
);
ok($add, 'create');
$add->dump_status_messages(1);
ok(!$add->execute, 'execute');

note('Fail - Add already existing instrument data');
$add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'instrument_data',
    'values' => [qw/ 2sep09.934pmaa1 /],
);
ok($add, 'create');
$add->dump_status_messages(1);
ok(!$add->execute, 'execute');

# BUILD
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
my $build = Genome::Model::Build->create(
    model => $model,
    data_directory => $tmpdir,
);
ok($build, 'create build');
is_deeply([$build->instrument_data], [$model->instrument_data], 'copied instrument data');
my $master_event = Genome::Model::Event->create(
    event_type => 'genome model build',
    event_status => 'Successful',
    model => $model,
    build => $build,
    user_name => $ENV{USER},
    date_scheduled => UR::Time->now,
    date_completed => UR::Time->now,
);
ok($master_event, 'created master event');
is_deeply($build->the_master_event, $master_event, 'got master event from build');

note('Fail - input object does exist');
$add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'instrument_data',
    'values' =>[qw/ 2sep09.934noexist /],
);
ok($add, 'create');
$add->dump_status_messages(1);
ok(!$add->execute, 'execute');

# REMOVE
note('Remove single value, and abandon builds');
my $remove =Genome::Model::Command::Input::Remove->create(
    model => $model,
    name => 'instrument_data',
    'values' => [qw/ 2sep09.934pmaa1 /],
);
ok($remove, 'create');
ok($remove->execute, 'execute');
@instrument_data = $model->instrument_data;
is(@instrument_data, 1, 'removed instrument data');
is($build->status, 'Abandoned', 'abandoned build');

note('Fail - remove singlular property');
$remove =Genome::Model::Command::Input::Remove->create(
    model => $model,
    name => 'center_name', 
    'values' => [qw/ none /],
);
ok($remove, 'create');
ok(!$remove->execute);

note('Fail - remove input not linked anymore');
$remove =Genome::Model::Command::Input::Remove->create(
    model => $model,
    name => 'instrument_data',
    'values' => [qw/ 2sep09.934pmaa1 /],
);
ok($remove, 'create');
ok(!$remove->execute);

done_testing();
exit;

