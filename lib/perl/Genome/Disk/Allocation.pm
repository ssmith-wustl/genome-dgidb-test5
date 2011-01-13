package Genome::Disk::Allocation;

use strict;
use warnings;

use Genome;

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
            calculate => q{
                return Genome::Disk::Volume->get(mount_path => $mount_path);
            },
        }
    ],
    table_name => 'GENOME_DISK_ALLOCATION',
    data_source => 'Genome::DataSource::GMSchema',
};

our $MINIMUM_ALLOCATION_SIZE = 0;
our $MAX_ATTEMPTS_TO_LOCK_VOLUME = 3;
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
    my $class = shift;
    my $path = shift;
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

    # Make sure that required parameters are provided
    my @missing_params;
    for my $param (@REQUIRED_PARAMETERS) {
        unless (exists $params{$param} and defined $params{$param}) {
            push @missing_params, $param;
        }
    }
    if (@missing_params) {
        Carp::confess "Missing required params for allocation:\n" . join("\n", @missing_params);
    }
        
    # Verify the owner
    unless ($params{owner_class_name}->__meta__) {
        Carp::confess "Could not find meta information for owner class " . $params{owner_class_name} .
            ", make sure this class exists!";
    }

    # Verify that kilobytes requested isn't something wonky
    my $kilobytes_requested = $params{kilobytes_requested};
    if ($params{kilobytes_requested} < $MINIMUM_ALLOCATION_SIZE) {
        Carp::confess "Allocation size of $kilobytes_requested kb is less than minimum of $MINIMUM_ALLOCATION_SIZE" ;
    }

    # Verify the supplied group name is valid
    my $disk_group_name = $params{disk_group_name};
    unless (grep { $disk_group_name eq $_ } @APIPE_DISK_GROUPS) {
        Carp::confess "Can only allocate disk in apipe disk groups, not $disk_group_name. Apipe groups are\n:" . join("\n", @APIPE_DISK_GROUPS);
    }
    my $group = Genome::Disk::Group->get(disk_group_name => $disk_group_name);
    unless ($group) {
        Carp::confess "Could not find a group with name $disk_group_name";
    }
    $params{group_subdirectory} = $group->subdirectory;

    # Make sure that there isn't a parent allocation (ie, that none of the allocation path's 
    # parent directories have themselves been allocated).
    unless (Genome::Disk::Allocation->verify_no_parent_allocation($params{allocation_path})) {
        Carp::confess "Parent allocation found for " . $params{allocation_path};
    }

    # Make several attempts to lock a volume, then give up and die
    my $attempts = 0;
    my $volume;
    while ($attempts < $MAX_ATTEMPTS_TO_LOCK_VOLUME) {
         

        my $mount_path = $params{mount_path};
        # If given a mount path, need to ensure it's valid by trying to get a disk volume with it. Also need to
        # make sure that the retrieved volume actually belongs to the supplied disk group
        if (defined $mount_path) {
            $mount_path =~ s/\/$//;
            $volume = Genome::Disk::Volume->get(mount_path => $mount_path);
            if ($volume and !(grep { $_ eq $disk_group_name } $volume->disk_group_names)) {
                Carp::confess "Volume with mount path $mount_path is not in supplied group $disk_group_name!";
            }
            elsif (!$volume) {
                Carp::confess "Could not get volume with mount path $mount_path!";
            }
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
                Carp::confess "Did not get any allocatable and active volumes belonging to group $disk_group_name with " .
                    "$kilobytes_requested kb of unallocated space!";
            }

            # Sort volumes by most recent allocation, we are interested in the least recently allocated volume
            @volumes = sort { $a->id <=> $b->id } map { $_->most_recent_allocation } @volumes;
            $volume = $volumes[0];
        }

        # Lock row in Disk::Volume using filesystem lock
        my $lock_id = '/gsc/var/lock/allocation/volume_' . $volume->id;
        my $lock = Genome::Utility::FileSystem->lock_resource(
            resource_lock => $lock_id,
            max_try => 3,
            block_sleep => 3,
        );
        $attempts++ and next unless defined $lock;
        
        # Reload volume, if anything has changed restart (there's a small window between looking at the volume
        # and locking it in which someone could modify it)
        my ($can_allocate, $disk_status) = ($volume->can_allocate, $volume->disk_status);
        $volume = Genome::Disk::Volume->load($volume->id);
        unless($volume->unallocated_kb < $kilobytes_requested and $volume->can_allocate eq $can_allocate
                and $volume->disk_status eq $disk_status) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock);
            $attempts++;
            next;
        }
    
        # Add a commit hook so this lock is released upon successful commit
        $volume->add_observer(
            aspect => 'commit',
            callback => sub {
                Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock);
            },
        );

        # We've got our volume locked, let's continue
        last;
    }

    if ($attempts >= $MAX_ATTEMPTS_TO_LOCK_VOLUME) {
        Carp::confess "Tried and failed $attempts times to lock a volume for allocation, giving up";
    }

    # Can now safely update this parameter since we have the volume
    $params{mount_path} = $volume->mount_path;

    # Decrement the available space on the volume
    $volume->unallocated_kb($volume->unallocated_kb - $kilobytes_requested);

    # Now finalize creation of the allocation object
    my $self = $class->SUPER::create(%params);
    unless ($self) {
        Carp::confess "Could not create allocation with params: " . Data::Dumper::Dumper(\%params);
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
