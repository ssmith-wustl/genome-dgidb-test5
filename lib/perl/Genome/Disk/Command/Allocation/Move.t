#!/usr/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Temp 'tempdir';

use_ok('Genome::Disk::Command::Allocation::Move') or die;
use_ok('Genome::Disk::Allocation') or die;

$Genome::Disk::Allocation::CREATE_DUMMY_VOLUMES_FOR_TESTING = 1;

my $group = Genome::Disk::Group->create(
    disk_group_name => 'testing',
    subdirectory => 'testing',
    permissions => '755',
    sticky => 1,
    unix_uid => 0,
    unix_gid => 0,
);
ok($group, 'created test group');
push @Genome::Disk::Allocation::APIPE_DISK_GROUPS, $group->disk_group_name;

# Temp testing directory, used as mount path for test volumes and allocations
my $test_dir_base = '/gsc/var/cache/testsuite/running_testsuites/';
my $test_dir = tempdir(
    TEMPLATE => 'allocation_testing_XXXXXX',
    DIR => $test_dir_base,
    UNLINK => 1,
    CLEANUP => 1,
);

# Create temp mount path for testing volume
my $volume_path = tempdir(
    TEMPLATE => "test_volume_XXXXXXX",
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
my $volume = Genome::Disk::Volume->create(
    hostname => 'test',
    physical_path => 'test',
    mount_path => $volume_path,
    disk_status => 'active',
    can_allocate => 1,
    total_kb => 1000,
    unallocated_kb => 1000,
);
ok($volume, 'created test volume');

# Create another temp mount path for another testing volume
my $other_volume_path = tempdir(
    TEMPLATE => "test_volume_XXXXXXX",
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
my $other_volume = Genome::Disk::Volume->create(
    hostname => 'test',
    physical_path => 'test',
    mount_path => $other_volume_path,
    disk_status => 'active',
    can_allocate => 1,
    total_kb => 1000,
    unallocated_kb => 1000,
);
ok($other_volume, 'created another test volume');

# Add volumes to test group
my $assignment = Genome::Disk::Assignment->create(
    volume => $volume,
    group => $group,
);
ok($assignment, 'assigned first test volume to group');
Genome::Sys->create_directory(join('/', $volume->mount_path, $group->subdirectory));

my $other_assignment = Genome::Disk::Assignment->create(
    volume => $other_volume,
    group => $group,
);
ok($other_assignment, 'add second test volume to group');
Genome::Sys->create_directory(join('/', $other_volume->mount_path, $group->subdirectory));

# Make test allocation
my $allocation_path = tempdir(
    TEMPLATE => "allocation_test_1_XXXXXX",
    CLEANUP => 1,
    UNLINK => 1,
);
my $allocation = Genome::Disk::Allocation->create(
    mount_path => $volume->mount_path,
    disk_group_name => $group->disk_group_name,
    allocation_path => $allocation_path,
    kilobytes_requested => 100,
    owner_class_name => 'UR::Value',
    owner_id => 'test',
);
ok($allocation, 'created test allocation');

# Create and exeucte move command object
my $cmd = Genome::Disk::Command::Allocation::Move->create(
    allocations => [$allocation],
    target_volume => $other_volume,
);
ok($cmd, 'created move command successfully');
ok($cmd->execute, 'executed command');
is($allocation->volume->id, $other_volume->id, 'allocation successfully moved to other volume');

# Now simulate the command being run from the CLI
my @args = ('genome', 'disk', 'allocation', 'move', '--target-volume', 'mount_path=' . $volume->mount_path, $allocation->id);
my $rv = Genome::Disk::Command::Allocation::Move->_execute_with_shell_params_and_return_exit_code(@args);
ok($rv == 0, 'successfully executed command using simulated command line arguments');
is($allocation->volume->id, $volume->id, 'allocation updated as expected after move');

done_testing();



