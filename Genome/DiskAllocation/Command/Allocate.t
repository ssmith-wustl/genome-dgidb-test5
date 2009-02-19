#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 16;

use GSCApp;
App::DB->db_access_level('rw');
App::DB::TableRow->use_dummy_autogenerated_ids(1);
App::DBI->no_commit(1);
App->init;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok('Genome::DiskAllocation');
use_ok('Genome::DiskAllocation::Command::Allocate');

my $fake_mount_path = '/incorrect/mount/path';
my $allocation_path = '/testing/allocate';

my $mock_id = 0;
my $mock_pp = Genome::ProcessingProfile->create_mock(id => --$mock_id);
my $mock_model = Genome::Model->create_mock(
                                            genome_model_id => --$mock_id,
                                            id => $mock_id,
                                            processing_profile_id => $mock_pp->id,
                                            subject_name => 'test_subject_name',
                                            subject_type => 'test_subject_type',
                                            name => 'test_model_name',
                                        );
my $mock_build = Genome::Model::Build->create_mock(
                                                   build_id => --$mock_id,
                                                   id => $mock_id,
                                                   model_id => $mock_model->genome_model_id,
                                               );
is(Genome::DiskAllocation::Command::Allocate->disk_group_name,'info_apipe','got disk group name as class method');
isa_ok(Genome::DiskAllocation::Command::Allocate->get_disk_group,'GSC::DiskGroup');

my $disk_allocation;

# Test an incorrect mount path param
eval {
    $disk_allocation = Genome::DiskAllocation::Command::Allocate->create(mount_path => $fake_mount_path);
};
ok(scalar(grep { "Disk mount path '$fake_mount_path' is not an available disk mount path"} $@),'mount path not found');

# Test no params
eval {
    $disk_allocation = Genome::DiskAllocation::Command::Allocate->create();
};
ok(scalar(grep { 'Owner class name is required!' } $@),'owner class name is required');

# Test correct owner class name but missing owner id
my %allocate_params = (
                       owner_class_name => 'Genome::Model::Build',
                   );
eval {
    $disk_allocation = Genome::DiskAllocation::Command::Allocate->create(%allocate_params);
};
ok(scalar(grep { 'Owner id is required!' } $@),'owner id is required');

# Test incorrect owner id
$allocate_params{'owner_id'} = --$mock_id;
eval {
    $disk_allocation = Genome::DiskAllocation::Command::Allocate->create(%allocate_params);
};
ok(scalar(grep { 'Failed to get object of class Genome::Model::Build and id '. $mock_id } $@),'failed to get owner object');

# Test with out allocation path
$allocate_params{'owner_id'} = $mock_build->id;
eval {
    $disk_allocation = Genome::DiskAllocation::Command::Allocate->create(%allocate_params);
};
ok(scalar(grep { 'Allocation path is required!' } $@), 'allocation path is required');

$allocate_params{'allocation_path'} = $allocation_path;
eval {
    $disk_allocation = Genome::DiskAllocation::Command::Allocate->create(%allocate_params);
};
ok(scalar(grep { 'Kilobytes requested is required!'} $@), 'kilobytes requested is required');

$allocate_params{'kilobytes_requested'} = '100';
$DB::single = 1;
eval {
    $disk_allocation = Genome::DiskAllocation::Command::Allocate->create(%allocate_params);
};
isa_ok($disk_allocation,'Genome::DiskAllocation::Command::Allocate');
ok($disk_allocation->execute,'execute allocate disk space');

my $lock;
eval {
    $lock = Genome::DiskAllocation::Command::Allocate->lock(block_sleep => 1,max_try => 2);
};
ok(!$lock,'existing lock has not been removed yet');

# This doesn't trigger the subscription callback to unlock the allocation resource
UR::Context->_sync_databases;
# I tried an actual commit, but again it did not trigger the subscription callback
#UR::Context->commit;

my $unlock;
eval {
    $unlock = $disk_allocation->unlock;
};
ok($unlock,'remove the existing disk allocation lock');

eval {
    $lock = Genome::DiskAllocation::Command::Allocate->lock(block_sleep => 1,max_try => 2);
};
ok($lock,'existing lock was removed new one in place');
eval {
    $unlock = Genome::DiskAllocation::Command::Allocate->unlock;
};
ok($unlock,'cleanup the new lock');

exit;
