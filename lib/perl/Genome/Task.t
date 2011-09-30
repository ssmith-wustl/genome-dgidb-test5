#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use above "Genome";
use Command;
use Test::More;
use Test::Differences;
use File::Path;
use Fcntl ':mode';
use JSON::XS;

$ENV{TEST_MODE} = 1;
$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

plan tests => 3;

my $task_params = {filter=>'name~boberkfe%'};

my $bad_task = Genome::Task->create(command_class=>'Genome::Model::Build::Command::Start', status=>'pending', params=>encode_json({models=>99999999999999}), user_id=>'boberkfe', time_submitted=>UR::Time->now);
ok(!defined $bad_task, "no task created for bad params");

my $good_task = Genome::Task->create(command_class=>'Genome::Model::Build::Command::Start', status=>'pending', params=>encode_json({models=>2880146303}), user_id=>'boberkfe', time_submitted=>UR::Time->now);
ok($good_task, "task created for good params");

my $another_task = Genome::Task->create(command_class=>'Genome::Model::Command::List', status=>'pending', params=>encode_json($task_params), user_id=>'boberkfe', time_submitted=>UR::Time->now);
ok($another_task, "created task");

