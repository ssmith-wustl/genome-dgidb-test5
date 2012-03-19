#!/usr/bin/perl

package Genome::Disk::Allocation;

use strict;
use warnings;

use Genome;
use File::Copy::Recursive 'dircopy';
use Carp 'confess';

class Genome::Disk::Allocation {
    id_generator => '-uuid',
    id_by => [
        id => {
            is => 'Text',
            doc => 'The id for the allocator event',
        },
    ],
    has => [
        disk_group_name => {
            is => 'Text',
            doc => 'The name of the disk group',
        },
        mount_path => {
            is => 'Text',
            doc => 'The mount path of the disk volume',
        },
        allocation_path => {
            is => 'Text',
            doc => 'The sub-dir of the disk volume for which space is allocated',
        },
        kilobytes_requested => {
            is => 'Number',
            doc => 'The disk space allocated in kilobytes',
        },
        owner_class_name => {
            is => 'Text',
            doc => 'The class name for the owner of this allocation',
        },
        owner_id => {
            is => 'Text',
            doc => 'The id for the owner of this allocation',
        },
        owner => { 
            id_by => 'owner_id', 
            is => 'UR::Object', 
            id_class_by => 'owner_class_name' 
        },
        group_subdirectory => {
            is => 'Text',
            doc => 'The group specific subdirectory where space is allocated',
        },
        absolute_path => {
            calculate_from => ['mount_path','group_subdirectory','allocation_path'],
            calculate => q{ return $mount_path .'/'. $group_subdirectory .'/'. $allocation_path; },
        },
        volume => { 
            is => 'Genome::Disk::Volume',
            calculate_from => 'mount_path',
            calculate => q| return Genome::Disk::Volume->get(mount_path => $mount_path, disk_status => 'active'); |
        },
        group => {
            is => 'Genome::Disk::Group',
            calculate_from => 'disk_group_name',
            calculate => q| return Genome::Disk::Group->get(disk_group_name => $disk_group_name); |,
        },
    ],
    has_optional => [
        original_kilobytes_requested => {
            is => 'Number',
            doc => 'The disk space allocated in kilobytes',
        },
        kilobytes_used => {
            is => 'Number',
            default => 0,
            doc => 'The actual disk space used by owner',
        },
        creation_time => {
            is => 'DateTime',
            doc => 'Time at which the allocation was created',
        },
        reallocation_time => {
            is => 'DateTime',
            doc => 'The last time at which the allocation was reallocated',
        },
        owner_exists => {
            is => 'Boolean',
            calculate_from => ['owner_class_name', 'owner_id'],
            calculate => q| 
                my $owner_exists = eval { $owner_class_name->get($owner_id) }; 
                return $owner_exists ? 1 : 0; 
            |,
        }
    ],    
    table_name => 'GENOME_DISK_ALLOCATION',
    data_source => 'Genome::DataSource::GMSchema',
};

# TODO This needs to be removed, site-specific
our @APIPE_DISK_GROUPS = qw/
    info_apipe
    info_apipe_ref
    info_alignments
    info_genome_models
    systems_benchmarking
/;
our $CREATE_DUMMY_VOLUMES_FOR_TESTING = 1;
my $MAX_VOLUMES = 5;
my $MINIMUM_ALLOCATION_SIZE = 0;
my $MAX_ATTEMPTS_TO_LOCK_VOLUME = 30;
my @PATHS_TO_REMOVE; # Keeps track of paths created when no commit is on
my @REQUIRED_PARAMETERS = qw/
    disk_group_name
    allocation_path
    kilobytes_requested
    owner_class_name
    owner_id
/;

sub allocate { return shift->create(@_); }
sub create {
    my ($class, %params) = @_;

    # TODO Switch from %params to BoolExpr and pass in BX to autogenerate_new_object_id
    unless (exists $params{allocation_id}) {
        $params{allocation_id} = $class->__meta__->autogenerate_new_object_id;
    }

    # If no commit is on, make a dummy volume to allocate to
    if ($ENV{UR_DBI_NO_COMMIT}) {
        if ($CREATE_DUMMY_VOLUMES_FOR_TESTING) {
            my $tmp_volume = Genome::Disk::Volume->create_dummy_volume(
                mount_path => $params{mount_path},
                disk_group_name => $params{disk_group_name},
            );
            $params{mount_path} = $tmp_volume->mount_path;
        }
    }

    my $self = $class->_execute_system_command('_create', %params);

    if ($ENV{UR_DBI_NO_COMMIT}) {
        push @PATHS_TO_REMOVE, $self->absolute_path;
    }
    else {
        $self->_log_change_for_rollback;
    }

    return $self;
}

sub deallocate { return shift->delete(@_); }
sub delete {
    my ($class, %params) = @_;
    $class->_execute_system_command('_delete', %params);
    return 1;
}

sub reallocate {
    my ($class, %params) = @_;
    return $class->_execute_system_command('_reallocate', %params);
}

sub move {
    my ($class, %params) = @_;
    return $class->_execute_system_command('_move', %params);
}

sub archive {
    my ($class, %params) = @_;
    return $class->_execute_system_command('_archive', %params);
}

sub unarchive {
    my ($class, %params) = @_;
    return $class->_execute_system_command('_unarchive', %params);
}

sub is_archived {
    my $self = shift;
    return $self->volume->is_archive;
}

sub archive_path {
    my $self = shift;
    return join('/', $self->absolute_path, 'archive.tar');
}

sub _create {
    my $class = shift;
    my %params = @_;

    # Make sure that required parameters are provided
    my @missing_params;
    for my $param (@REQUIRED_PARAMETERS) {
        unless (exists $params{$param} and defined $params{$param}) {
            push @missing_params, $param;
        }
    }
    if (@missing_params) {
        confess "Missing required params for allocation:\n" . join("\n", @missing_params);
    }

    # Make sure there aren't any extra params
    my $id = delete $params{allocation_id};
    $id = $class->__meta__->autogenerate_new_object_id unless defined $id; # TODO autogenerate_new_object_id should technically receive a BoolExpr
    my $kilobytes_requested = delete $params{kilobytes_requested};
    my $owner_class_name = delete $params{owner_class_name};
    my $owner_id = delete $params{owner_id};
    my $allocation_path = delete $params{allocation_path};
    my $disk_group_name = delete $params{disk_group_name};
    my $mount_path = delete $params{mount_path};
    my $group_subdirectory = delete $params{group_subdirectory};
    my $kilobytes_used = delete $params{kilobytes_used} || 0;
    if (%params) {
        confess "Extra parameters detected: " . Data::Dumper::Dumper(\%params);
    }

    unless ($owner_class_name->__meta__) {
        confess "Could not find meta information for owner class $owner_class_name, make sure this class exists!";
    }
    unless ($class->_check_kb_requested($kilobytes_requested)) {
        confess 'Kilobytes requested is not valid!';
    }
    unless ($class->_verify_no_parent_allocation($allocation_path)) {
        confess "Parent allocation found for $allocation_path";
    }
    unless ($class->_verify_no_child_allocations($allocation_path)) {
        confess "Child allocation found for $allocation_path!";
    }
    unless (grep { $disk_group_name eq $_ } @APIPE_DISK_GROUPS) {
        confess "Can only allocate disk in apipe disk groups, not $disk_group_name. Apipe groups are: " . join(", ", @APIPE_DISK_GROUPS);
    }

    my $group = Genome::Disk::Group->get(disk_group_name => $disk_group_name);
    confess "Could not find a group with name $disk_group_name" unless $group;
    if (defined $group_subdirectory and $group_subdirectory ne $group->subdirectory) {
        print STDERR "Given group subdirectory $group_subdirectory does not match retrieved group's subdirectory, ignoring provided value\n";
    }
    $group_subdirectory = $group->subdirectory;

    # If given a mount path, need to ensure it's valid by trying to get a disk volume with it. Also need to make
    # sure that the retrieved volume actually belongs to the supplied disk group and that it can be allocated to
    my @candidate_volumes; 
    if (defined $mount_path) {
        $mount_path =~ s/\/$//; # mount paths in database don't have trailing /
        my $volume = Genome::Disk::Volume->get(mount_path => $mount_path, disk_status => 'active', can_allocate => 1);
        confess "Could not get volume with mount path $mount_path" unless $volume;

        unless (grep { $_ eq $disk_group_name } $volume->disk_group_names) {
            confess "Volume with mount path $mount_path is not in supplied group $disk_group_name!";
        }

        my @reasons;
        push @reasons, 'disk is not active' if $volume->disk_status ne 'active';
        push @reasons, 'allocation turned off for this disk' if $volume->can_allocate != 1;
        push @reasons, 'not enough space on disk' if ($volume->unallocated_kb - $volume->unallocatable_reserve_size) < $kilobytes_requested;
        if (@reasons) {
            confess "Requested volume with mount path $mount_path cannot be allocated to:\n" . join("\n", @reasons);
        }

        push @candidate_volumes, $volume;
    }
    # If not given a mount path, get all the volumes that belong to the supplied group that have enough space and
    # pick one at random from the top MAX_VOLUMES. It's been decided that we want to fill up a small subset of volumes
    # at a time instead of all of them.
    else {
        push @candidate_volumes, $class->_get_candidate_volumes(
            disk_group_name => $disk_group_name,
            kilobytes_requested => $kilobytes_requested
        );
    }

    # Now pick a volume and try to lock it
    my ($volume, $volume_lock) = $class->_lock_volume_from_list($kilobytes_requested, @candidate_volumes);

    # Decrement the available space on the volume and create allocation object
    $volume->unallocated_kb($volume->unallocated_kb - $kilobytes_requested);
    my $self = $class->SUPER::create(
        mount_path => $volume->mount_path,
        disk_group_name => $disk_group_name,
        kilobytes_requested => $kilobytes_requested,
        original_kilobytes_requested => $kilobytes_requested,
        allocation_path => $allocation_path,
        owner_class_name => $owner_class_name,
        owner_id => $owner_id,
        group_subdirectory => $group_subdirectory,
        id => $id,
        creation_time => UR::Time->now,
    );
    unless ($self) {
        Genome::Sys->unlock_resource(resource_lock => $volume_lock);
        confess "Could not create allocation!";
    }

    $self->status_message("Allocation " . $self->id . " created at " . $self->absolute_path);

    # Add commit hooks to unlock and create directory (in that order)
    $class->_create_observer(
        $class->_unlock_closure($volume_lock), 
        $class->_create_directory_closure($self->absolute_path),
    );
    return $self;
}

sub _delete {
    my ($class, %params) = @_;
    my $id = delete $params{allocation_id};
    confess "Require allocation ID!" unless defined $id;
    if (%params) {
        confess "Extra params found: " . Data::Dumper::Dumper(\%params);
    }

    # Lock and retrieve allocation
    my $allocation_lock = $class->get_lock($id);
    confess 'Could not get lock for allocation ' . $id unless defined $allocation_lock;

    my $self = $class->get($id);
    unless ($self) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess "Could not find allocation with id $id" unless $self;
    }
    my $absolute_path = $self->absolute_path;

    $self->status_message("Beginning deallocation process for allocation " . $self->id);

    # Lock and retrieve volume
    my $volume_lock = Genome::Disk::Volume->get_lock($self->mount_path, 3600);
    unless ($volume_lock) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock on volume ' . $self->mount_path;
    }
    my $mode = $self->_retrieve_mode;
    my $volume = Genome::Disk::Volume->$mode(mount_path => $self->mount_path, disk_status => 'active');
    unless ($volume) {
        Genome::Sys->unlock_resource(resource_lock => $volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Found no disk volume with mount path ' . $self->mount_path;
    }

    # Update
    $volume->unallocated_kb($volume->unallocated_kb + $self->kilobytes_requested);
    $self->SUPER::delete;

    # Add commit hooks to remove locks, mark for deletion, and deletion
    $class->_create_observer(
        $class->_unlock_closure($volume_lock, $allocation_lock),
        $class->_mark_for_deletion_closure($absolute_path),
        $class->_remove_directory_closure($absolute_path),
    );
    return 1;
}

# Changes the size of the allocation and updates the volume appropriately
sub _reallocate {
    my ($class, %params) = @_;
    my $id = delete $params{allocation_id};
    confess "Require allocation ID!" unless defined $id;
    my $kilobytes_requested = delete $params{kilobytes_requested};
    my $kilobytes_requested_is_actual_disk_usage = 0;
    my $allow_reallocate_with_move = delete $params{allow_reallocate_with_move};
    if (%params) {
        confess "Found extra params: " . Data::Dumper::Dumper(\%params);
    }

    # Lock and retrieve allocation
    my $allocation_lock = $class->get_lock($id);
    confess "Could not get lock on allocation $id" unless defined $allocation_lock;

    my $mode = $class->_retrieve_mode;
    my $self = $class->$mode($id);
    unless ($self) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess "Could not find allocation $id";
    }

    $self->status_message("Beginning reallocation process for allocation " . $self->id);

    # Either check the new size (if given) or get the current size of the allocation directory
    if (defined $kilobytes_requested) {
        unless ($self->_check_kb_requested($kilobytes_requested)) {
            Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
            confess 'Kilobytes requested not valid!';
        }
    }
    else {
        $self->status_message('New allocation size not supplied, setting to size of data in allocated directory');
        if (-d $self->absolute_path) {
            $kilobytes_requested = Genome::Sys->disk_usage_for_path($self->absolute_path);
        }
        else {
            $kilobytes_requested = 0;
        }
        unless (defined $kilobytes_requested) {
            Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
            confess 'Could not determine size of allocation directory ' . $self->absolute_path;
        }
        $kilobytes_requested_is_actual_disk_usage = 1;
    }

    my $diff = $kilobytes_requested - $self->kilobytes_requested;
    $self->status_message("Resizing from " . $self->kilobytes_requested . " kb to $kilobytes_requested kb (changed by $diff)"); 

    # Lock and retrieve volume
    my $volume_lock = Genome::Disk::Volume->get_lock($self->mount_path, 3600);
    unless (defined $volume_lock) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock on volume ' . $self->mount_path;
    }

    my $volume = Genome::Disk::Volume->$mode(mount_path => $self->mount_path, disk_status => 'active');
    unless ($volume) {
        Genome::Sys->unlock_resource(resource_lock => $volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get volume with mount path ' . $self->mount_path;
    }

    # If there's enough space, just change the size, no worries!
    my $available_space = $volume->unallocated_kb - $volume->unusable_reserve_size;
    if ($kilobytes_requested == 0 or $diff < 0 or ($diff <= $available_space)) {
        $self->kilobytes_requested($kilobytes_requested);
        $volume->unallocated_kb($volume->unallocated_kb - $diff);
        $self->reallocation_time(UR::Time->now);
        $class->_create_observer($class->_unlock_closure($volume_lock, $allocation_lock));
    }
    else {
        # Move the allocation to a new disk if allowed to do so
        if ($allow_reallocate_with_move) {
            Genome::Sys->unlock_resource(resource_lock => $volume_lock);
            Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
            return $self->_move(
                kilobytes_requested => $kilobytes_requested,
                allocation_id => $id,
            );
        }
        # If our kb requested value was determined via du, the allocation size should still be increased so we have an accurate
        # record of the data on the disk. Reallocation shouldn't fail in this case, since all it's trying to do is reflect
        # the actual amount of data on the disk
        elsif ($kilobytes_requested_is_actual_disk_usage) {
            $self->warning_message("Increasing size of allocation despite volume not having enough allocatable space for accurate tracking!");
            $self->kilobytes_requested($kilobytes_requested);
            $volume->unallocated_kb($volume->unallocated_kb - $diff);
            $self->reallocation_time(UR::Time->now);
            $class->_create_observer($class->_unlock_closure($volume_lock, $allocation_lock));
        }
        else {
            Genome::Sys->unlock_resource(resource_lock => $volume_lock);
            Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
            confess 'Not enough unallocated space on volume ' . $volume->mount_path . " to increase allocation size by $diff kb";
        }
    }
    return 1;
}

# Move an allocation from one volume to another
sub _move {
    my ($class, %params) = @_;
    my $id = delete $params{allocation_id};
    my $kilobytes_requested = delete $params{kilobytes_requested};
    my $group_name = delete $params{disk_group_name};
    my $new_mount_path = delete $params{target_mount_path};
    my $pattern = delete $params{pattern};
    if (%params) {
        confess "Extra parameters given to allocation move method: " . join(',', sort keys %params);
    }

    # Lock and retrieve allocation
    my $allocation_lock = Genome::Disk::Allocation->get_lock($id);
    unless ($allocation_lock) {
        confess "Could not lock allocation with ID $id";
    }
    my $mode = $class->_retrieve_mode;
    my $self = Genome::Disk::Allocation->$mode($id);
    unless ($self) {
        confess "Found no allocation with ID $id";
    }

    # Set some defaults, record current state
    $group_name = $self->disk_group_name unless $group_name;
    $kilobytes_requested = Genome::Sys->disk_usage_for_path($self->absolute_path) unless $kilobytes_requested;
    my $original_allocation_size = $self->kilobytes_requested;
    my $old_volume = $self->volume;

    # Lock and retrieve volume, either the one provided by the caller or any volume with enough space in the group
    my $new_volume;
    my $new_volume_lock;
    if ($new_mount_path) {
        if ($new_mount_path eq $self->mount_path) {
            confess "Target volume $new_mount_path matches current mount path, cannot move!";
        }

        $new_volume_lock = Genome::Disk::Volume->get_lock($new_mount_path);
        unless ($new_volume_lock) {
            confess "Could not get lock for volume $new_mount_path";
        }
        $new_volume = Genome::Disk::Volume->$mode(mount_path => $new_mount_path, disk_status => 'active', can_allocate => 1);
        unless ($new_volume) {
            confess "Could not find an active and allocatable volume with mount path $new_mount_path";
        }
    }
    else {
        my @candidate_volumes = $self->_get_candidate_volumes(
            disk_group_name => $group_name, 
            kilobytes_requested => $kilobytes_requested,
            reallocating => 1,
            exclude => [$self->mount_path],
        );
        ($new_volume, $new_volume_lock) = $self->_lock_volume_from_list($kilobytes_requested, @candidate_volumes);
    }
    my $old_allocation_dir = $self->absolute_path;
    my $base_volume_path = join('/', $new_volume->mount_path, $new_volume->groups->subdirectory);
    my $new_allocation_dir = join('/', $base_volume_path, $self->allocation_path);

    unless (Genome::Sys->validate_directory_for_read_write_access($base_volume_path)) {
        Genome::Sys->unlock_resource(resource_lock => $new_volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess "Cannot write to target volume, cannot move data!";
    }

    unless (-d $new_allocation_dir) {
        unless (Genome::Sys->create_directory($new_allocation_dir)) {
            confess "Could not create new allocation directory $new_allocation_dir!";
        }
    }

    $self->status_message("Moving allocation " . $self->id . " from volume " . $old_volume->mount_path . " to a new volume");

    # Update new volume, commit changes, release locks
    $new_volume->unallocated_kb($new_volume->unallocated_kb - $kilobytes_requested);
    $self->_create_observer($self->_unlock_closure($new_volume_lock));
    unless (UR::Context->commit) {
        Genome::Sys->unlock_resource(resource_lock => $new_volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not update target volume ' . $new_volume->mount_path;
    }

    # If rollback occurs, need to increment size of new volume
    my $volume_change = UR::Context::Transaction->log_change(
        $self, 'UR::Value', $self->id, 'external_change', sub { $new_volume->unallocated_kb($new_volume->unallocated_kb + $kilobytes_requested) }
    );

    # Now copy data to the new location
    $self->status_message("Copying data from $old_allocation_dir to $new_allocation_dir");
    push @PATHS_TO_REMOVE, $new_allocation_dir; # If the process dies while copying, need to clean up the new directory
    my $copy_rv = eval { 
        Genome::Sys->copy_directory_tree(
            source_directory => $old_allocation_dir,
            target_directory => $new_allocation_dir,
            file_pattern => $pattern,
        )
    };
    unless ($copy_rv) {
        Genome::Sys->remove_directory_tree($new_allocation_dir) if -d $new_allocation_dir;
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not copy allocation ' . $self->id . " from $old_allocation_dir to $new_allocation_dir : $!";
    }

    # Lock new volume, update allocation, commit changes, release locks
    $new_volume_lock = Genome::Disk::Volume->get_lock($new_volume->mount_path, 3600);
    unless (defined $new_volume_lock) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock for volume ' . $new_volume->mount_path;
    }
    $self->mount_path($new_volume->mount_path);
    $self->group_subdirectory($new_volume->groups->subdirectory);
    $self->kilobytes_requested($kilobytes_requested);
    $self->reallocation_time(UR::Time->now);
    $self->_update_owner_for_move;
    $self->_create_observer($self->_unlock_closure($new_volume_lock, $allocation_lock));
    unless (UR::Context->commit) {
        Genome::Sys->remove_directory_tree($new_allocation_dir);
        Genome::Sys->unlock_resource(resource_lock => $new_volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not commit move of allocation ' . $self->id . " from $old_allocation_dir to $new_allocation_dir";
    }
    pop @PATHS_TO_REMOVE; # No longer need to remove new directory, changes are committed

    # Delete data from old volume, lock old volume, update avaiable space, return (which will commit and release locks)
    unless (Genome::Sys->remove_directory_tree($old_allocation_dir)) {
        confess "Could not remove old allocation data at $old_allocation_dir for allocation " . $self->id;
    }
    my $old_volume_lock = Genome::Disk::Volume->get_lock($old_volume->mount_path, 3600);
    unless (defined $old_volume_lock) {
        confess 'Could not get lock for volume ' . $old_volume->mount_path;
    }
    $old_volume->unallocated_kb($old_volume->unallocated_kb + $original_allocation_size);
    $self->_create_observer($self->_unlock_closure($old_volume_lock));
    return 1;
}

sub _archive {
    my ($class, %params) = @_;
    my $id = delete $params{allocation_id};
    if (%params) {
        confess "Extra parameters given to allocation move method: " . join(',', sort keys %params);
    }

    my $mode = $class->_retrieve_mode;
    my $self = Genome::Disk::Allocation->$mode($id);
    unless ($self) {
        confess "Found no allocation with ID $id";
    }

    my $tar_rv = Genome::Sys->tar(
        tar_path => $self->archive_path,
        input_directory => $self->absolute_path,
    );
    unless ($tar_rv) {
        confess "Could not create tarball for allocation contents!";
    }

    my $tar_file = File::Basename::basename($self->archive_path);
    my $rv = $self->_move(
        allocation_id => $id,
        target_mount_path => $self->volume->archive_mount_path,
        kilobytes_requested => $self->kilobytes_requested,
        pattern => $tar_file,
    );
    unless ($rv) {
        confess "Could not archive allocation " . $self->id . ", failed to move it from " .
            $self->mount_path . " to " . $self->volume->archive_mount_path;
    }
    
    return 1;
}

sub _unarchive {
    my ($class, %params) = @_;
    my $id = delete $params{allocation_id};
    if (%params) {
        confess "Extra parameters given to allocation unarchive method: " . join(',', sort keys %params);
    }

    my $mode = $class->_retrieve_mode;
    my $self = Genome::Disk::Allocation->$mode($id);
    unless ($self) {
        confess "Found no allocation with ID $id";
    }

    my $rv = $self->_move(
        allocation_id => $self->id,
        target_mount_path => $self->volume->active_mount_path,
        kilobytes_requested => $self->kilobytes_requested,
    );
    unless ($rv) {
        confess "Could not unarchive allocation " . $self->id . ", failed to move it from " .
            $self->volume->archive_mount_path . " to " . $self->volume->active_mount_path;
    }

    my $untar_rv = Genome::Sys->untar(
        tar_path => $self->archive_path,
        target_directory => $self->absolute_path,
        delete_tar => 1,
    );
    unless ($untar_rv) {
        confess "Could not untar tarball at " . $self->absolute_path;
    }
    return 1;
}

# Locks the allocation, if lock is not manually released (it had better be!) it'll be automatically
# cleaned up on program exit
sub get_lock {
    my ($class, $id, $tries) = @_;
    $tries ||= 60;
    my $allocation_lock = Genome::Sys->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/allocation_' . join('_', split(' ', $id)),
        max_try => $tries,
        block_sleep => 1,
    );
    return $allocation_lock;
}

sub has_valid_owner {
    my $self = shift;
    my $meta = $self->owner_class_name->__meta__;
    return 0 unless $meta;
    return 1;
}

sub __display_name__ {
    my $self = shift;
    return $self->absolute_path;
}

# Using a system call when not in dev mode is a hack to get around the fact that we don't
# have software transactions. Allocation need to be able to make its changes and commit
# immediately so locks can be released in a timely manner. Without software transactions,
# the only two ways of doing this are to: just commit away, or create a subprocess and commit
# there. Comitting in the calling process makes it possible for objects in an intermediate
# state to be committed unintentionally (for example, if a user makes an object of type Foo, 
# then creates an allocation for it, and then intends to finish instantiating it after), 
# which can either lead to outright rejection by the database if a constraint is violated or 
# other more subtle problems in the software. So, that leaves making a subprocess, which is 
# slow but won't lead to other problems.
sub _execute_system_command {
    my ($class, $method, %params) = @_;
    if (ref($class)) {
        $params{allocation_id} = $class->id;
        $class = ref($class);
    }
    confess "Require allocation ID!" unless exists $params{allocation_id};

    my $allocation;
    if ($ENV{UR_DBI_NO_COMMIT}) {
        $allocation = $class->$method(%params);
    }
    else {
        # Serialize params hash, construct command, and execute
        my $param_string = Genome::Utility::Text::hash_to_string(\%params);
        my $includes = join(' ', map { '-I ' . $_ } UR::Util::used_libs);
        my $cmd = "perl $includes -e \"use above Genome; $class->$method($param_string); UR::Context->commit;\"";

        unless (eval { system($cmd) } == 0) {
            confess "Could not perform allocation action!";
        }
        $allocation = $class->_reload_allocation($params{allocation_id});
    }

    return $allocation;
}

sub _log_change_for_rollback {
    my $self = shift;
    # If the owner gets rolled back, then delete the allocation. Make sure the allocation hasn't already been deleted,
    # which can happen if the owner is coded well and cleans up its own mess during rollback.
    my $remove_sub = sub {
        my $allocation_id = $self->id;
        $self->unload;
        my $loaded_allocation = Genome::Disk::Allocation->get($allocation_id);
        $loaded_allocation->delete if ($loaded_allocation);
    };
    my $allocation_change = UR::Context::Transaction->log_change(
        $self->owner, 'UR::Value', $self->id, 'external_change', $remove_sub,
    );
    return 1;
}

# Some owners track their absolute path separately from the allocation, which means they also need to be
# updated when the allocation is moved. That special logic goes here
sub _update_owner_for_move {
    my $self = shift;
    my $owner = $self->owner;
    return 1 unless $owner;

    if ($owner->isa('Genome::SoftwareResult')) {
        $owner->output_dir($self->absolute_path);
    }
    elsif ($owner->isa('Genome::Model::Build')) {
        $owner->data_directory($self->absolute_path);
    }

    return 1;
}

# Unloads the allocation and then reloads to ensure that changes from database are retrieved
sub _reload_allocation {
    my ($class, $id) = @_;
    my $mode = $class->_retrieve_mode;
    return Genome::Disk::Allocation->$mode($id);
}

# Creates an observer that executes the supplied closures
sub _create_observer {
    my ($class, @closures) = @_;
    my $observer;
    my $callback = sub {
        $observer->delete if $observer;
        for my $closure (@closures) {
            &$closure;
        }
    };

    if ($ENV{UR_DBI_NO_COMMIT}) {
        &$callback;
        return 1;
    }

    $observer = UR::Context->add_observer(
        aspect => 'commit',
        callback => $callback,
    );
    return 1;
}

# Returns a closure that removes the given locks 
sub _unlock_closure {
    my ($class, @locks) = @_;
    return sub {
        for my $lock (@locks) {
            Genome::Sys->unlock_resource(resource_lock => $lock) if -e $lock;
        }
    };
}

# Returns a closure that creates a directory at the given path
sub _create_directory_closure {
    my ($class, $path) = @_;
    return sub {
        # This method currently returns the path if it already exists instead of failing
        my $dir = eval{ Genome::Sys->create_directory($path) };
        if (defined $dir and -d $dir) {
            chmod(02775, $dir);
            print STDERR "Created allocation directory at $path\n";
        }
        else {
            print STDERR "Could not create allocation directcory at $path!\n";
            print "$@\n" if $@;
        }
    };
}

# Returns a closure that removes the given directory
sub _remove_directory_closure {
    my ($class, $path) = @_;
    return sub {
        if (-d $path and not $ENV{UR_DBI_NO_COMMIT}) {
            print STDERR "Removing allocation directory $path\n";
            my $rv = Genome::Sys->remove_directory_tree($path);
            unless (defined $rv and $rv == 1) {
                confess "Could not remove allocation directory $path!";
            }
        }
    };
}

# Make a file at the root of the allocation directory indicating that the allocation is gone,
# which makes it possible to figure out which directories should have been deleted but failed.
sub _mark_for_deletion_closure {
    my ($class, $path) = @_;
    return sub {
        if (-d $path and not $ENV{UR_DBI_NO_COMMIT}) {
            print STDERR "Marking directory at $path as deallocated\n";
            system("touch $path/ALLOCATION_DELETED"); 
        }
    };
}

# Class method for determining if the given path has a parent allocation
sub _verify_no_parent_allocation {
    my ($class, $path) = @_;
    my ($allocation) = $class->get(allocation_path => $path);
    return 0 if $allocation;

    my $dir = File::Basename::dirname($path);
    if ($dir ne '.' and $dir ne '/') {
        return $class->_verify_no_parent_allocation($dir);
    }
    return 1;
}

# Checks for allocations beneath this one, which is also invalid
sub _verify_no_child_allocations {
    my ($class, $path) = @_;
    $path =~ s/\/+$//;
    my ($allocation) = $class->get('allocation_path like' => $path . '/%');
    return 0 if $allocation;
    return 1;
}

# Makes sure the supplied kb amount is valid (nonzero and bigger than mininum)
sub _check_kb_requested {
    my ($class, $kb) = @_;
    return 0 unless defined $kb;
    return 0 if $kb < $MINIMUM_ALLOCATION_SIZE;
    return 1;
}

# Returns a list of volumes that meets the given criteria
sub _get_candidate_volumes {
    my ($class, %params) = @_;
    my $disk_group_name = delete $params{disk_group_name};
    my $kilobytes_requested = delete $params{kilobytes_requested};
    my $reallocating = delete $params{reallocating};
    my $exclude = delete $params{exclude};
    $reallocating ||= 0;

    my %volume_params = (
        disk_group_names => $disk_group_name,
        'unallocated_kb >=' => $kilobytes_requested,
        can_allocate => 1,
        disk_status => 'active',
    );
    $volume_params{'mount_path not in'} = $exclude if $exclude;
    my @volumes = Genome::Disk::Volume->get(%volume_params);
    unless (@volumes) {
        confess "Did not get any allocatable and active volumes belonging to group $disk_group_name with " .
            "$kilobytes_requested kb of unallocated space!";
    }

    # Make sure that the allocation doesn't infringe on the empty buffer required for each volume. Reallocations
    # can use up to 98% of a disk, but new allocations can only use up to 95%.
    @volumes = grep {
        my $reserve_size = ($reallocating ? $_->unusable_reserve_size : $_->unallocatable_reserve_size);
        ($_->unallocated_kb - $reserve_size) > $kilobytes_requested
    } @volumes;
    unless (@volumes) {
        confess "No volumes of group $disk_group_name have enough space after excluding reserves to store $kilobytes_requested KB.";
    }

    @volumes = sort { $a->unallocated_kb <=> $b->unallocated_kb } @volumes;

    # Only allocate to the first MAX_VOLUMES retrieved
    my $max = @volumes > $MAX_VOLUMES ? $MAX_VOLUMES : @volumes;
    @volumes = @volumes[0..($max - 1)];
    return @volumes;
}

# Locks and returns a volume from the provided list
sub _lock_volume_from_list {
    my ($self, $kilobytes_requested, @candidate_volumes) = @_;
    confess "No volumes to choose from!" unless @candidate_volumes;

    my $volume;
    my $volume_lock;
    my $attempts = 0;
    while (1) {
        if ($attempts++ > $MAX_ATTEMPTS_TO_LOCK_VOLUME) {
            confess "Could not lock a volume after $MAX_ATTEMPTS_TO_LOCK_VOLUME attempts, giving up";
        }

        # Pick a random volume from the list of candidates and try to lock it
        my $index = int(rand(@candidate_volumes));
        my $candidate_volume = $candidate_volumes[$index];
        my $lock = Genome::Disk::Volume->get_lock($candidate_volume->mount_path);
        next unless defined $lock;

        # Reload volume, if anything has changed restart (there's a small window between looking at the volume
        # and locking it in which someone could modify it)
        my $mode = $self->_retrieve_mode;
        $candidate_volume = Genome::Disk::Volume->$mode($candidate_volume->id);
        unless($candidate_volume->unallocated_kb >= $kilobytes_requested 
                and $candidate_volume->can_allocate eq '1' 
                and $candidate_volume->disk_status eq 'active') {
            Genome::Sys->unlock_resource(resource_lock => $lock);
            next;
        }

        $volume = $candidate_volume;
        $volume_lock = $lock;
        last;
    }

    return ($volume, $volume_lock);
}

# When no commit is on, ordinarily an allocation goes to a dummy volume that only exists locally. Trying to load
# that dummy volume would lead to an error, so use a get instead.
sub _retrieve_mode {
    return 'get' if $ENV{UR_DBI_NO_COMMIT};
    return 'load';
}

# Cleans up directories, useful when no commit is on and the test doesn't clean up its allocation directories
# or in the case of reallocate with move when a copy fails and temp data needs to be removed
END {
    remove_test_paths();
}
sub remove_test_paths {
    for my $path (@PATHS_TO_REMOVE) {
        next unless -d $path;
        Genome::Sys->remove_directory_tree($path);
        if ($ENV{UR_DBI_NO_COMMIT}) {
            print STDERR "Removing allocation path $path because UR_DBI_NO_COMMIT is on\n";
        }
        else {
            print STDERR "Cleaning up allocation path $path\n";
        }
    }
}

1;
