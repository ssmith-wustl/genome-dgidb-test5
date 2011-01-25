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

our $MAX_VOLUMES = 5;
our $MINIMUM_ALLOCATION_SIZE = 0;
our $MAX_ATTEMPTS_TO_LOCK_VOLUME = 30;
our @REQUIRED_PARAMETERS = qw/
    disk_group_name
    allocation_path
    kilobytes_requested
    owner_class_name
    owner_id
/;
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

# Class method for determining if the given path has a parent allocation
sub verify_no_parent_allocation {
    my ($class, $path) = @_;
    my ($allocation) = Genome::Disk::Allocation->get(allocation_path => $path);
    return 0 if $allocation;

    my $dir = File::Basename::dirname($path);
    if ($dir ne '.' and $dir ne '/') {
        return Genome::Disk::Allocation->verify_no_parent_allocation($dir);
    }
    return 1;
}

# Makes sure the supplied kb amount is valid
sub check_kb_requested {
    my ($class, $kb) = @_;
    return unless defined $kb;
    return if $kb < $MINIMUM_ALLOCATION_SIZE;
    return 1;
}

# FIXME This emulates the old style locking for allocations, which uses select for update. This can
# be phased out as soon as I'm sure that the new style is being used everywhere
sub select_group_for_update {
    my ($class, $group_id) = @_;
    return 1 if $ENV{UR_DBI_NO_COMMIT};
    GSC::DiskVolume->load(sql => qq{
        select dv.* from disk_volume dv
        join disk_volume_group dvg on dv.dv_id = dvg.dv_id
        and dvg.dg_id = $group_id
        for update
    });
    return 1;
}

# FIXME Same as above method, but locks the volume instead of the group
sub select_volume_for_update {
    my ($class, $volume_id) = @_;
    return 1 if $ENV{UR_DBI_NO_COMMIT};
    GSC::DiskVolume->load(sql => qq{
        select * from disk_volume
        where dv_id = $volume_id
        for update
    });
    return 1;
}

sub create_observer_for_unlock {
    my ($class, @locks) = @_;
    my $observer;
    my $callback = sub {
        for my $lock (@locks) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock);
        }
        print STDERR "Releasing locks, allocation process complete\n";
        $observer->delete;
    };
    $observer = UR::Context->add_observer(
        aspect => 'commit',
        callback => $callback,
    );
    return 1;
}

sub get_volume_lock {
    my ($class, $mount_path) = @_;
    my $modified_mount = $mount_path;
    $modified_mount =~ s/\//_/g;
    my $volume_lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/volume' . $modified_mount,
        max_try => 10,
        block_sleep => 2,
    );
    return $volume_lock;
}

sub get_allocation_lock {
    my ($class, $id) = @_;
    my $allocation_lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/allocation_' . join('_', split(' ', $id)),
        max_try => 5,
        block_sleep => 2,
    );
    return $allocation_lock;
}

sub allocate { return $_[0]->create(@_) }
sub create {
    my $class = shift;
    my %params = @_;

    print STDERR "Beginning allocation process\n";
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
        
    # Verify the owner
    unless ($params{owner_class_name}->__meta__) {
        confess "Could not find meta information for owner class " . $params{owner_class_name} .
            ", make sure this class exists!";
    }

    # Verify that kilobytes requested isn't something wonky
    unless (Genome::Disk::Allocation->check_kb_requested($params{kilobytes_requested})) {
        confess 'Kilobytes requested is not valid!';
    }
    my $kilobytes_requested = $params{kilobytes_requested};

    # Make sure that there isn't a parent allocation (ie, that none of the allocation path's 
    # parent directories have themselves been allocated)
    unless (Genome::Disk::Allocation->verify_no_parent_allocation($params{allocation_path})) {
        confess "Parent allocation found for " . $params{allocation_path};
    }

    # Verify the supplied group name is valid
    my $disk_group_name = $params{disk_group_name};
    unless (grep { $disk_group_name eq $_ } @APIPE_DISK_GROUPS) {
        confess "Can only allocate disk in apipe disk groups, not $disk_group_name. Apipe groups are: " . join(", ", @APIPE_DISK_GROUPS);
    }

    # Get the group
    my $group = Genome::Disk::Group->get(disk_group_name => $disk_group_name);
    confess "Could not find a group with name $disk_group_name" unless $group;
    $params{group_subdirectory} = $group->subdirectory;

    my @candidate_volumes; 
    my $mount_path = $params{mount_path};
    # If given a mount path, need to ensure it's valid by trying to get a disk volume with it. Also need to
    # make sure that the retrieved volume actually belongs to the supplied disk group and that it can
    # be allocated to
    if (defined $mount_path) {
        $mount_path =~ s/\/$//; # mount paths in database don't have trailing /
        my $volume = Genome::Disk::Volume->get(mount_path => $mount_path);
        confess "Could not get volume with mount path $mount_path" unless $volume;

        # FIXME Temporarily use LIMS style locking, uses a select for update
        Genome::Disk::Allocation->select_volume_for_update($volume->id);

        unless (grep { $_ eq $disk_group_name } $volume->disk_group_names) {
            confess "Volume with mount path $mount_path is not in supplied group $disk_group_name!";
        }

        # Make sure the volume is allocatable
        my @reasons;
        push @reasons, 'disk is not active' if $volume->disk_status ne 'active';
        push @reasons, 'allocation turned off for this disk' if $volume->can_allocate != 1;
        push @reasons, 'not enough space on disk' if $volume->unallocated_kb < $kilobytes_requested;
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
        Genome::Disk::Allocation->select_group_for_update($group->id);

        # Get all volumes that meet our criteria
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

        # Pick a random volume from the list of candidates
        my $index = int(rand(@candidate_volumes));
        my $candidate_volume = $candidate_volumes[$index];

        # Lock using mount path, necessary so other allocation command don't have to first load the volume
        # to get other information, lock it, and then reload. Here, this is unavoidable.
        my $lock = Genome::Disk::Allocation->get_volume_lock($candidate_volume->mount_path);
        next unless defined $lock;

        # Reload volume, if anything has changed restart (there's a small window between looking at the volume
        # and locking it in which someone could modify it)
        my ($can_allocate, $disk_status) = ($candidate_volume->can_allocate, $candidate_volume->disk_status);
        $candidate_volume = Genome::Disk::Volume->load($candidate_volume->id);
        unless($candidate_volume->unallocated_kb >= $kilobytes_requested 
                and $candidate_volume->can_allocate eq $can_allocate
                and $candidate_volume->disk_status eq $disk_status
                and grep { $_ eq $disk_group_name } $candidate_volume->disk_group_names) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock);
            next;
        }

        print STDERR "Locked volume " . $candidate_volume->mount_path . "\n";
        $volume = $candidate_volume;
        $volume_lock = $lock;
        last;
    }

    # Can now safely update this parameter since we have the volume
    $params{mount_path} = $volume->mount_path;

    # Decrement the available space on the volume
    $volume->unallocated_kb($volume->unallocated_kb - $kilobytes_requested);

    # Now finalize creation of the allocation object
    my $self = $class->SUPER::create(%params);
    unless ($self) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
        confess "Could not create allocation with params: " . Data::Dumper::Dumper(\%params);
    }

    # Add a commit hook to create allocation path. If UR_DBI_NO_COMMIT is set, then this won't fire.
    my $dir_observer;
    my $dir_callback = sub {
        my $dir = Genome::Utility::FileSystem->create_directory($self->absolute_path);
        unless (defined $dir and -d $dir) {
            $self->error_message("Could not create allocation directory tree " . $self->absolute_path);
        }
        else {
            $self->status_message("Allocation directory created at " . $self->absolute_path);
        }
        $dir_observer->delete; # To prevent multiple executions of the observer
    };
    $dir_observer = $self->add_observer(
        aspect => 'commit',
        callback => $dir_callback,
    );

    # Add a commit hook so this lock is released upon successful commit. This is added to the context and not
    # the object so it fires even if UR_DBI_NO_COMMIT is set
    $self->create_observer_for_unlock($volume_lock);

    return $self;
}

sub deallocate { return $_[0]->delete(@_) }
sub delete {
    my $self = shift;
    my %params = @_;
    my $remove_allocation_directory = $params{remove_allocation_directory} || 1;
    $remove_allocation_directory = 0 if $ENV{UR_DBI_NO_COMMIT};

    $self->status_message('Starting deallocation process');

    # Lock and retrieve allocation
    my $allocation_lock = $self->get_allocation_lock($self->id);
    confess 'Could not get lock for allocation ' . $self->id unless defined $allocation_lock;

    # Reload self to make sure there aren't any updates
    my $id = $self->id;
    $self = Genome::Disk::Allocation->load($id);
    unless ($self) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess "Could not reload allocation $id from database" unless $self;
    }

    $self->status_message('Locked and retrieved allocation ' . $self->id);

    # Remove allocation directory
    my $path = $self->absolute_path;
    if ($remove_allocation_directory and -d $path) {
        $self->status_message("Removing allocation directory $path");
        my $rv = Genome::Utility::FileSystem->remove_directory_tree($self->absolute_path);
        unless (defined $rv and $rv == 1) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
            confess "Could not remove allocation directory $path!";
        }
    }
    else {
        $self->status_message("Not removing allocation directory");
    }

    # Lock volume and update
    my $volume_lock = $self->get_volume_lock($self->mount_path);
    unless ($volume_lock) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock on volume ' . $self->mount_path;
    }
    my $volume = Genome::Disk::Volume->get(mount_path => $self->mount_path);
    unless ($volume) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Found no disk volume with mount path ' . $self->mount_path;
    }

    # FIXME Lock volume using old LIMS style, this is temporary
    $self->select_volume_for_update($volume->id);

    $self->status_message('Locked and retrieved volume ' . $self->mount_path . ', removing allocation and updating volume');
    $volume->unallocated_kb($volume->unallocated_kb + $self->kilobytes_requested);
    $self->SUPER::delete;

    Genome::Disk::Allocation->create_observer_for_unlock($volume_lock, $allocation_lock);
    return 1;
}

# Changes the size of the allocation and updates the volume appropriately
sub reallocate {
    my ($self, %params) = @_;
    my $kilobytes_requested = $params{kilobytes_requested};

    my $allocation_lock = $self->get_allocation_lock($self->id);
    confess 'Could not get lock on allocation ' . $self->id unless defined $allocation_lock;

    # Reload self, make sure there aren't any updates (mostly worried about deallocation)
    my $id = $self->id;
    $self = Genome::Disk::Allocation->get($id);
    unless ($self) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess "Could not reload allocation $id after acquiring lock!";
    }

    $self->status_message('Locked and retrieved allocation ' . $self->id);

    # Either check the new size (if given) or get the current size of the allocation directory
    if (defined $kilobytes_requested) {
        unless ($self->check_kb_requested($kilobytes_requested)) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
            confess 'Kilobytes requested not valid!';
        }
    }
    else {
        $self->status_message('New allocation size not supplied, setting to size of data in allocated directory');
        $kilobytes_requested = Genome::Utility::FileSystem->disk_usage_for_path($self->absolute_path);
        unless (defined $kilobytes_requested) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
            confess 'Could not determine size of allocation directory ' . $self->absolute_path;
        }
    }

    my $diff = $kilobytes_requested - $self->kilobytes_requested;

    # Lock and retrieve volume
    my $volume_lock = $self->get_volume_lock($self->mount_path);
    unless (defined $volume_lock) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock on volume ' . $self->mount_path;
    }

    my $volume = Genome::Disk::Volume->get(mount_path => $self->mount_path);
    unless ($volume) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get volume with mount path ' . $self->mount_path;
    }

    # FIXME Get LIMS style lock, this is temporary
    $self->select_volume_for_update($volume->id);

    $self->status_message('Acquired volume lock and retrieved volume');

    # Make sure there's room for the allocation... only applies if the new allocation is bigger than the old
    unless ($volume->unallocated_kb >= $diff) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Not enough unallocated space on volume ' . $volume->mount_path . " to increase allocation size by $diff kb";
    }

    # Update allocation and volume
    $self->kilobytes_requested($kilobytes_requested);
    $volume->unallocated_kb($volume->unallocated_kb - $diff);

    $self->create_observer_for_unlock($volume_lock, $allocation_lock);
    return 1;
}

1;
