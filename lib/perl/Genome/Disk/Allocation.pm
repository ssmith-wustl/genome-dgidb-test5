package Genome::Disk::Allocation;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Disk::Allocation {
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
            calculate => q|
                return $mount_path .'/'. $group_subdirectory .'/'. $allocation_path;
            |,
        },
        volume => { 
            is => 'Genome::Disk::Volume',
            calculate_from => 'mount_path',
            calculate => q| return Genome::Disk::Volume->get(mount_path => $mount_path); |
        },
        group => {
            is => 'Genome::Disk::Group',
            calculate_from => 'disk_group_name',
            calculate => q| return Genome::Disk::Group->get(disk_group_name => $disk_group_name); |,
        },
    ],
    has_optional => [
        kilobytes_used => {
            is => 'Number',
            default => 0,
            doc => 'The actual disk space used by owner',
        },
    ],    
    table_name => 'GENOME_DISK_ALLOCATION',
    data_source => 'Genome::DataSource::GMSchema',
};

my $MAX_VOLUMES = 5;
my $MINIMUM_ALLOCATION_SIZE = 0;
my $MAX_ATTEMPTS_TO_LOCK_VOLUME = 30;
my @REQUIRED_PARAMETERS = qw/
    disk_group_name
    allocation_path
    kilobytes_requested
    owner_class_name
    owner_id
/;

# TODO This needs to be removed, site-specific
our @APIPE_DISK_GROUPS = qw/
    info_apipe
    info_apipe_ref
    info_alignments
    info_genome_models
/;

# This generates a unique text ID for the object. The format is <hostname> <PID> <time in seconds> <some number>
sub Genome::Disk::Allocation::Type::autogenerate_new_object_id {
    return $UR::Object::Type::autogenerate_id_base . ' ' . (++$UR::Object::Type::autogenerate_id_iter);
}

# The allocation process should be done in a separate process to ensure it completes and commits quickly, since
# locks on allocations and volumes persist until commit completes. To make this invisible to everyone, the
# create/delete/reallocate methods perform the system calls that execute _create/_delete/_reallocate methods.
sub allocate { return shift->create(@_); }
sub create {
    my ($class, %params) = @_;
    unless (exists $params{id}) {
        $params{id} = Genome::Disk::Allocation::Type::autogenerate_new_object_id;
    }

    # If no commit is on, the created object won't be retrievable via a get (since it will only live in the
    # child process' UR object cache). Just call the _create method directly and return
    if ($ENV{UR_DBI_NO_COMMIT}) {
        return $class->_create(%params);
    }

    $DB::single = 1;
    # Serialize hash and create allocation via system call to ensure commit occurs
    my $param_string = Genome::Utility::Text::hash_to_string(\%params);
    my $includes = join(' ', map { '-I ' . $_ } UR::Util::used_libs);
    my $rv = system("perl $includes -e \"use above Genome; $class->_create($param_string); UR::Context->commit;\"");
    confess "Could not create allocation" unless $rv == 0;

    my $allocation = $class->get(id => $params{id});
    confess "Could not retrieve created allocation with id " . $params{id} unless $allocation;
    
    # If the owner gets rolled back, then delete the allocation
    my $allocation_change = UR::Context::Transaction->log_change(
        $allocation->owner, 'UR::Value', $allocation->id, 'external_change', sub { $allocation->delete },
    );
    # Not being able to roll back the allocation shouldn't be grounds for failure methinks
    unless ($allocation_change) { 
        print STDERR "Failed to record allocation creation!\n";
    }

    return $allocation;    
}

sub deallocate { return shift->delete(@_); }
sub delete {
    my ($class, %params) = @_;
    if (ref($class)) {
        $params{allocation_id} = $class->id;
        $class = ref($class);
    }
    confess "Require allocation ID" unless exists $params{allocation_id};

    # Same as above... if no commit is on, just call the _delete method directly so changes will be in UR cache
    if ($ENV{UR_DBI_NO_COMMIT}) {
        return $class->_delete(%params);
    }

    my $param_string = Genome::Utility::Text::hash_to_string(\%params);
    my $includes = join(' ', map { '-I ' . $_ } UR::Util::used_libs);
    my $rv = system("perl $includes -e \"use above Genome; $class->_delete($param_string); UR::Context->commit;\"");
    confess "Could not deallocate" unless $rv == 0;
    return 1;
}

sub reallocate {
    my ($class, %params) = @_;
    if (ref($class)) {
        $params{allocation_id} = $class->id;
        $class = ref($class);
    }
    confess "Require allocation ID!" unless exists $params{allocation_id};

    # Again, call _reallocate directly if no commit is on so changes occur in UR cache
    if ($ENV{UR_DBI_NO_COMMIT}) {
        return $class->_reallocate(%params);
    }

    my $param_string = Genome::Utility::Text::hash_to_string(\%params);
    my $includes = join(' ', map { '-I ' . $_ } UR::Util::used_libs);
    my $rv = system("perl $includes -e \"use above Genome; $class->_reallocate($param_string); UR::Context->commit;\"");
    confess "Could not reallocate!" unless $rv == 0;
    return 1;
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

    my $id = delete $params{id};
    $id = Genome::Disk::Allocation::Type::autogenerate_new_object_id unless defined $id;
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
    unless ($class->check_kb_requested($kilobytes_requested)) {
        confess 'Kilobytes requested is not valid!';
    }
    unless ($class->verify_no_parent_allocation($allocation_path)) {
        confess "Parent allocation found for $allocation_path";
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
        my $volume = Genome::Disk::Volume->get(mount_path => $mount_path);
        confess "Could not get volume with mount path $mount_path" unless $volume;

        # FIXME Temporarily use LIMS style locking, uses a select for update
        $class->select_volume_for_update($volume->id);

        unless (grep { $_ eq $disk_group_name } $volume->disk_group_names) {
            confess "Volume with mount path $mount_path is not in supplied group $disk_group_name!";
        }

        my @reasons;
        push @reasons, 'disk is not active' if $volume->disk_status ne 'active';
        push @reasons, 'allocation turned off for this disk' if $volume->can_allocate != 1;
        push @reasons, 'not enough space on disk' if ($volume->unallocated_kb - $volume->reserve_size) < $kilobytes_requested;
        if (@reasons) {
            confess "Requested volume with mount path $mount_path cannot be allocated to:\n" . join("\n", @reasons);
        }

        push @candidate_volumes, $volume;
    }
    # If not given a mount path, get all the volumes that belong to the supplied group that have enough space and
    # pick one at random from the top MAX_VOLUMES. It's been decided that we want to fill up a small subset of volumes
    # at a time instead of all of them.
    else {
        # FIXME Temporarily using LIMS style locking, uses a select for update
        $class->select_group_for_update($group->id);

        my @volumes = Genome::Disk::Volume->get(
            disk_group_names => $disk_group_name,
            'unallocated_kb >=' => $kilobytes_requested,
            can_allocate => 1,
            disk_status => 'active',
        );
        unless (@volumes) {
            confess "Did not get any allocatable and active volumes belonging to group $disk_group_name with " .
                "$kilobytes_requested kb of unallocated space!";
        }

        # Make sure that the allocation doesn't infringe on the empty buffer required for each volume
        @volumes = grep { ($_->unallocated_kb - $_->reserve_size) > $kilobytes_requested } @volumes;

        # Only allocate to the first MAX_VOLUMES retrieved
        my $max = @volumes > $MAX_VOLUMES ? $MAX_VOLUMES : @volumes;
        @volumes = @volumes[0,$max - 1];
        push @candidate_volumes, @volumes;
    }

    # Now pick a volume and try to lock it
    my $volume;
    my $volume_lock;
    my $attempts = 0;
    while (1) {
        if ($attempts > $MAX_ATTEMPTS_TO_LOCK_VOLUME) {
            confess "Could not lock a volume after $MAX_ATTEMPTS_TO_LOCK_VOLUME attempts, giving up";
        }
        $attempts++;

        # Pick a random volume from the list of candidates and try to lock it
        my $index = int(rand(@candidate_volumes));
        my $candidate_volume = $candidate_volumes[$index];
        my $lock = $class->get_volume_lock($candidate_volume->mount_path);
        next unless defined $lock;

        # Reload volume, if anything has changed restart (there's a small window between looking at the volume
        # and locking it in which someone could modify it)
        $candidate_volume = Genome::Disk::Volume->load($candidate_volume->id);
        unless($candidate_volume->unallocated_kb >= $kilobytes_requested 
                and $candidate_volume->can_allocate eq '1' 
                and $candidate_volume->disk_status eq 'active') {
            Genome::Sys->unlock_resource(resource_lock => $lock);
            next;
        }

        $volume = $candidate_volume;
        $volume_lock = $lock;
        $mount_path = $volume->mount_path;
        last;
    }

    # Decrement the available space on the volume and create allocation object
    $volume->unallocated_kb($volume->unallocated_kb - $kilobytes_requested);
    my $self = $class->SUPER::create(
        mount_path => $mount_path,
        disk_group_name => $disk_group_name,
        kilobytes_requested => $kilobytes_requested,
        allocation_path => $allocation_path,
        owner_class_name => $owner_class_name,
        owner_id => $owner_id,
        group_subdirectory => $group_subdirectory,
        id => $id,
    );
    unless ($self) {
        Genome::Sys->unlock_resource(resource_lock => $volume_lock);
        confess "Could not create allocation!";
    }

    $self->status_message("Allocation " . $self->id . " created at " . $self->absolute_path);

    # Add commit hooks to unlock and create directory (in that order)
    $class->create_observer(
        $class->unlock_closure($volume_lock), 
        $class->create_directory_closure($self->absolute_path),
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
    my $allocation_lock = $class->get_allocation_lock($id);
    confess 'Could not get lock for allocation ' . $id unless defined $allocation_lock;

    my $self = $class->get($id);
    unless ($self) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess "Could not find allocation with id $id" unless $self;
    }
    my $absolute_path = $self->absolute_path;

    $self->status_message("Beginning deallocation process for allocation " . $self->id);

    # Lock and retrieve volume
    my $volume_lock = $self->get_volume_lock($self->mount_path);
    unless ($volume_lock) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock on volume ' . $self->mount_path;
    }
    my $volume = Genome::Disk::Volume->get(mount_path => $self->mount_path);
    unless ($volume) {
        Genome::Sys->unlock_resource(resource_lock => $volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Found no disk volume with mount path ' . $self->mount_path;
    }

    # FIXME Lock volume using old LIMS style, this is temporary
    $self->select_volume_for_update($volume->id);

    # Update
    $volume->unallocated_kb($volume->unallocated_kb + $self->kilobytes_requested);
    $self->SUPER::delete;

    # Add commit hooks to remove locks, mark for deletion, and deletion
    $class->create_observer(
        $class->unlock_closure($volume_lock, $allocation_lock),
        $class->mark_for_deletion_closure($absolute_path),
        $class->remove_directory_closure($absolute_path),
    );
    return 1;
}

# Changes the size of the allocation and updates the volume appropriately
sub _reallocate {
    my ($class, %params) = @_;
    my $id = delete $params{allocation_id};
    confess "Require allocation ID!" unless defined $id;
    my $kilobytes_requested = delete $params{kilobytes_requested};
    if (%params) {
        confess "Found extra params: " . Data::Dumper::Dumper(\%params);
    }

    # Lock and retrieve allocation
    my $allocation_lock = $class->get_allocation_lock($id);
    confess "Could not get lock on allocation $id" unless defined $allocation_lock;

    my $self = $class->get($id);
    unless ($self) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess "Could not find allocation $id";
    }

    $self->status_message("Beginning reallocation process for allocation " . $self->id);

    # Either check the new size (if given) or get the current size of the allocation directory
    if (defined $kilobytes_requested) {
        unless ($self->check_kb_requested($kilobytes_requested)) {
            Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
            confess 'Kilobytes requested not valid!';
        }
    }
    else {
        $self->status_message('New allocation size not supplied, setting to size of data in allocated directory');
        $kilobytes_requested = Genome::Sys->disk_usage_for_path($self->absolute_path);
        unless (defined $kilobytes_requested) {
            Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
            confess 'Could not determine size of allocation directory ' . $self->absolute_path;
        }
    }

    my $diff = $kilobytes_requested - $self->kilobytes_requested;
    $self->status_message("Resizing from " . $self->kilobytes_requested . " kb to $kilobytes_requested kb (changed by $diff)"); 

    # Lock and retrieve volume
    my $volume_lock = $self->get_volume_lock($self->mount_path);
    unless (defined $volume_lock) {
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock on volume ' . $self->mount_path;
    }

    my $volume = Genome::Disk::Volume->get(mount_path => $self->mount_path);
    unless ($volume) {
        Genome::Sys->unlock_resource(resource_lock => $volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get volume with mount path ' . $self->mount_path;
    }

    # FIXME Get LIMS style lock, this is temporary
    $self->select_volume_for_update($volume->id);

    # Make sure there's room for the allocation... only applies if the new allocation is bigger than the old
    unless ($volume->unallocated_kb >= $diff) {
        Genome::Sys->unlock_resource(resource_lock => $volume_lock);
        Genome::Sys->unlock_resource(resource_lock => $allocation_lock);
        confess 'Not enough unallocated space on volume ' . $volume->mount_path . " to increase allocation size by $diff kb";
    }

    # Update allocation and volume, create unlock observer, and return
    $self->kilobytes_requested($kilobytes_requested);
    $volume->unallocated_kb($volume->unallocated_kb - $diff);

    $class->create_observer($class->unlock_closure($volume_lock, $allocation_lock));
    return 1;
}

# Creates an observer that executes the supplied closures
sub create_observer {
    my ($class, @closures) = @_;
    my $observer;
    my $callback = sub {
        for my $closure (@closures) {
            &$closure;
        }
        $observer->delete if $observer;
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
sub unlock_closure {
    my ($class, @locks) = @_;
    return sub {
        for my $lock (@locks) {
            Genome::Sys->unlock_resource(resource_lock => $lock);
        }
        print STDERR "Allocation locks released\n";
    };
}

# Returns a closure that creates a directory at the given path
sub create_directory_closure {
    my ($class, $path) = @_;
    return sub {
        # This method currently returns the path if it already exists instead of failing
        my $dir = Genome::Sys->create_directory($path);
        if (defined $dir and -d $dir) {
            chmod(0755, $dir);
            print STDERR "Created allocation directory at $path\n";
        }
        else {
            print STDERR "Could not create allocation directcory at $path!\n";
        }
    };
}

# Returns a closure that removes the given directory
sub remove_directory_closure {
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
sub mark_for_deletion_closure {
    my ($class, $path) = @_;
    return sub {
        if (-d $path) {
            print STDERR "Marking directory at $path as deallocated\n";
            system("touch $path/ALLOCATION_DELETED"); 
        }
    };
}

# Class method for determining if the given path has a parent allocation
sub verify_no_parent_allocation {
    my ($class, $path) = @_;
    my ($allocation) = $class->get(allocation_path => $path);
    return 0 if $allocation;

    my $dir = File::Basename::dirname($path);
    if ($dir ne '.' and $dir ne '/') {
        return $class->verify_no_parent_allocation($dir);
    }
    return 1;
}

# Makes sure the supplied kb amount is valid
sub check_kb_requested {
    my ($class, $kb) = @_;
    return 0 unless defined $kb;
    return 0 if $kb < $MINIMUM_ALLOCATION_SIZE;
    return 1;
}

# FIXME This emulates the old style locking for allocations, which uses select for update. This can
# be phased out as soon as I'm sure that the new style is being used everywhere
sub select_group_for_update {
    my ($class, $group_id) = @_;
    return 1 if $ENV{UR_DBI_NO_COMMIT};
    Genome::DataSource::Oltp->get_default_dbh->do(
        "select dv.* from disk_volume dv " .
        "join disk_volume_group dvg on dv.dv_id = dvg.dv_id " .
        "and dvg.dg_id = $group_id " .
        "for update"
    );
    return 1;
}

# FIXME Same as above method, but locks the volume instead of the group
sub select_volume_for_update {
    my ($class, $volume_id) = @_;
    return 1 if $ENV{UR_DBI_NO_COMMIT};
    Genome::DataSource::Oltp->get_default_dbh->do("select * from disk_volume where dv_id = $volume_id for update");
    return 1;
}

sub get_volume_lock {
    my ($class, $mount_path) = @_;
    my $modified_mount = $mount_path;
    $modified_mount =~ s/\//_/g;
    my $volume_lock = Genome::Sys->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/volume' . $modified_mount,
        max_try => 100,
        block_sleep => 1,
    );
    return $volume_lock;
}

sub get_allocation_lock {
    my ($class, $id) = @_;
    my $allocation_lock = Genome::Sys->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/allocation_' . join('_', split(' ', $id)),
        max_try => 20,
        block_sleep => 1,
    );
    return $allocation_lock;
}

1;
