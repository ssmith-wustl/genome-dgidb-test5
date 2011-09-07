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

plan tests=>5;

$ENV{TEST_MODE} = 1;
$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

my $task_params = {filter=>'name~boberkfe%'};
my $task = Genome::Task->create(command_class=>'Genome::Model::Command::List', status=>'pending', params=>encode_json($task_params), user_id=>'boberkfe', time_submitted=>UR::Time->now);
ok($task, "task created for good params");

my $tmp_dir = Genome::Sys->base_temp_directory();

my $run_cmd = Genome::Task::Command::Run->create(task=>$task, output_basedir=>$tmp_dir);
ok($run_cmd, "created run cmd successfully");

ok($run_cmd->execute, "executed cmd ok");

my $stdout_file = $tmp_dir . "/" . $task->id . "/stdout";

ok(-e $stdout_file, "redirected stdout file exists");
my $file_contents = `cat $stdout_file`;
ok($file_contents =~ m/NAME/, "stdout looks like what we would expect");

