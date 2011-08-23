#!/usr/bin/env perl
use strict;
use warnings;

# the "above" should only go in tests, and ensures you don't need to use -I
use above "Genome";

# init the test harness, and declare the number of tests we will run
use Test::More tests => 8;

# this ensures we don't talk to the database just to get new ID values for objects
# it will just use negative numbers instead of real IDs
$ENV{USE_DUMMY_AUTOGENERATED_IDS} = 1;
$ENV{UR_DBI_NO_COMMIT} = 1;

# ensure the module we will test compileis correctly before we start
use_ok("Genome::Model::Command::Update::RemoveBuild");

#
# make the test data 
#

my $s = Genome::Sample->create(id => -888, name => 'TEST-' . __FILE__ . "-$$");
ok($s, "made a test sample");

my $p = Genome::ProcessingProfile::TestPipeline->create(
    id => -999, 
    name => "test " . __FILE__ . " on host $ENV{HOSTNAME} process $$",
    some_command_name => 'ls',
);
ok($p, "made a test processing profile");

my $m = Genome::Model::TestPipeline->create(
    id => -1, 
    processing_profile_id => -999,
    subject_class_name => ref($s),
    subject_id => $s->id,
);
ok($m, "made a test model");

my $b1 = $m->add_build();
ok($b1, "made test build 1");

# run the command, and capture the exit code
# this way invokes the command right in this process, with an array of command-line arguments
# to test that we parse correctly
$ENV{GENOME_NO_REQUIRE_USER_VERIFY} = 1;
my $exit_code1 = eval { 
    Genome::Model::Build::Command::Remove->_execute_with_shell_params_and_return_exit_code('--', $b1->id);
};
$ENV{GENOME_NO_REQUIRE_USER_VERIFY} = 0;

# ensure it ran without errors
ok(!$@, "the command did not crash");
is($exit_code1, 0, "command believes it succeeded");
isa_ok($b1,"UR::DeletedRef", "build object is deleted");

=cut

# THIS TESTS THE MODEL'S LAST_SUCCEEDED_BUILD METHOD, BUT DOES NOT WORK YET

my $bdir = Genome::Sys->create_temp_directory();
ok(-d $bdir, "temp directory is $bdir on $ENV{HOSTNAME}");

my $b1 = $m->add_build(id => -2, data_directory => "$bdir/b1");
ok($b1, "made test build 1");
$b1->start();
is($b1->status, 'Succeeded', "status is correct");

my $b2 = $m->add_build(id => -3, data_directory => "$bdir/b2");
ok($b2, "made test build 1");
$b2->start();
is($b2->status, 'Succeeded', "status is correct");

my $b3 = $m->add_build(id => -4, data_directory => "$bdir/b3");
ok($b3, "made test build 1");
$b3->start();
is($b3->status, 'Succeeded', "status is correct");

is($m->last_succeeded_build, $b3, "last_succeeded_build is correct");

my $exit_code1 = Genome::Model::Build::Command::Remove->_execute_with_shell_params_and_return_exit_code($b2->id);
is($exit_code1, 0, "removal of build 2 command succeeded");
isa($b2,"UR::DeletedRef");
is($m->last_succeeded_build, $b3, "last_succeeded_build is still correct");

my $exit_code2 = Genome::Model::Build::Command::Remove->_execute_with_shell_params_and_return_exit_code($b3->id);
is($exit_code2, 0, "removal of build 3 command succeeded");
isa($b3,"UR::DeletedRef");
is($m->last_succeeded_build, $b1, "last_succeeded_build is now build 1");

=cut

