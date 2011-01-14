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
        kilobytes_used => {
            is => 'Number',
            doc => 'The actual disk space used by owner',
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
    table_name => 'GENOME_DISK_ALLOCATION',
    data_source => 'Genome::DataSource::GMSchema',
};

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

sub create {
    my $class = shift;
    my %params = @_;

    print STDERR "Beginning allocation process...\n";
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
    my $kilobytes_requested = $params{kilobytes_requested};
    if ($params{kilobytes_requested} < $MINIMUM_ALLOCATION_SIZE) {
        confess "Allocation size of $kilobytes_requested kb is less than minimum of $MINIMUM_ALLOCATION_SIZE" ;
    }

    # Make sure that there isn't a parent allocation (ie, that none of the allocation path's 
    # parent directories have themselves been allocated)
    unless (Genome::Disk::Allocation->verify_no_parent_allocation($params{allocation_path})) {
        confess "Parent allocation found for " . $params{allocation_path};
    }

    # Verify the supplied group name is valid
    my $disk_group_name = $params{disk_group_name};
    unless (grep { $disk_group_name eq $_ } @APIPE_DISK_GROUPS) {
        confess "Can only allocate disk in apipe disk groups, not $disk_group_name. Apipe groups are\n:" . join("\n", @APIPE_DISK_GROUPS);
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

        unless (grep { $_ eq $disk_group_name } $volume->disk_group_names) {
            confess "Volume with mount path $mount_path is not in supplied group $disk_group_name!";
        }

        # Make sure the volume is allocatable
        my @reasons;
        push @reasons, 'disk is not active' if $volume->disk_status != 'active';
        push @reasons, 'allocation turned off for this disk' if $volume->can_allocate != 0;
        push @reasons, 'not enough space on disk' if $volume->unallocated_kb < $kilobytes_requested;
        if (@reasons) {
            confess "Requested volume with mount path $mount_path cannot be allocated to:\n" . join("\n", @reasons);
        }

        push @candidate_volumes, $volume;
    }
    # If not given a mount path, get all the volumes that belong to the supplied group that have enough space and pick one
    else {
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

        my $modified_mount = $candidate_volume->mount_path;
        $modified_mount =~ s/\//_/g;
        my $lock = Genome::Utility::FileSystem->lock_resource(
            resource_lock => '/gsc/var/lock/allocation/volume_' . $modified_mount,
            max_try => 1,
            block_sleep => 0,
        );
        next unless defined $lock;

        # Reload volume, if anything has changed restart (there's a small window between looking at the volume
        # and locking it in which someone could modify it)
        my ($can_allocate, $disk_status) = ($candidate_volume->can_allocate, $candidate_volume->disk_status);
        $candidate_volume = Genome::Disk::Volume->load($candidate_volume->id);
        unless($candidate_volume->unallocated_kb < $kilobytes_requested and $candidate_volume->can_allocate eq $can_allocate
                and $candidate_volume->disk_status eq $disk_status and grep { $_ eq $disk_group_name } $volume->disk_group_names) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock);
            next;
        }

        print STDERR "Locked volume " . $candidate_volume->mount_path . "\n";
        $volume = $candidate_volume;
        $volume_lock = $lock;
        last;
    }

    # Add a commit hook so this lock is released upon successful commit
    $volume->add_observer(
        aspect => 'commit',
        callback => sub {
            print STDERR "Releasing volume lock\n";
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
        }
    );

    # Can now safely update this parameter since we have the volume
    $params{mount_path} = $volume->mount_path;

    # Decrement the available space on the volume
    $volume->unallocated_kb($volume->unallocated_kb - $kilobytes_requested);

    # Now finalize creation of the allocation object
    my $self = $class->SUPER::create(%params);
    unless ($self) {
        confess "Could not create allocation with params: " . Data::Dumper::Dumper(\%params);
    }

    # Add a commit hook to create allocation path unless no commit is on
    $self->add_observer(
        aspect => 'commit',
        callback => sub {
            my $dir = Genome::Utility::FileSystem->create_directory($self->absolute_path);
            $self->error_message("Could not create allocation directory tree " . $self->absolute_path);
        }
    ) unless $ENV{UR_DBI_NO_COMMIT} == 1;

    return $self;
}

1;
