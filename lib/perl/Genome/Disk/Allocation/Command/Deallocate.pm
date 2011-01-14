package Genome::Disk::Allocation::Command::Deallocate;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Disk::Allocation::Command::Deallocate {
    is => 'Genome::Disk::Allocation::Command',
    has => [
        allocation_id => {
            is => 'Number',
            doc => 'The id for the allocator event',
        },
        remove_allocation_directory => {
            is => 'Boolean',
            default => 1,
            doc => 'If set, the directory reserved by the allocation',
        },
    ],
    doc => 'Removes target allocation and deletes its directories',
};

sub help_brief {
    return 'Removes the target allocation and deletes its directories';
}

sub help_synopsis {
    return 'Removes the target allocation and deletes its directories';
}

sub help_detail {
    return 'Removes the target allocation and deletes its directories';
}

sub execute { 
    my $self = shift;
    $self->status_message('Starting deallocation process');

    # Lock and retrieve allocation
    my $allocation_lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/allocation_' . $self->allocation_id,
        max_try => 5,
        block_sleep => 1,
    );
    confess 'Could not get lock for allocation ' . $self->allocation_id unless defined $allocation_lock;

    my $allocation = Genome::Disk::Allocation->get($self->allocation_id);
    unless ($allocation) {
        confess $self->error_message('Found no allocation with id ' . $self->allocation_id);
    }

    $self->status_message('Locked and retrieved allocation' . $self->allocation_id);

    # Remove allocation directory
    my $path = $allocation->absolute_path;
    if ($self->remove_allocation_directory and -d $path) {
        $self->status_message("Removing allocation directory $path");
        my $rv = Genome::Utility::FileSystem->remove_directory_tree($allocation->absolute_path);
        confess "Could not remove allocation directory $path!" unless defined $rv and $rv == 1;
    }
    else {
        $self->status_message("Not removing allocation directory");
    }

    # Lock volume and update
    my $modified_mount = $allocation->mount_path;
    $modified_mount =~ s/\//_/g;
    my $volume_lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/volume_' . $modified_mount,
        max_try => 5,
        block_sleep => 1,
    );
    confess 'Could not get lock for volume ' . $allocation->mount_path;

    my $volume = Genome::Disk::Volume->get(mount_path => $allocation->mount_path);
    confess 'Found no disk volume with mount path ' . $allocation->mount_path;

    $self->status_message('Locked and retrieved volume ' . $allocation->mount_path . ', removing allocation and updating volume');

    $volume->unallocated_kb($volume->unallocated_kb + $allocation->kilobytes_requested);
    $allocation->delete;

    $volume->add_observer(
        aspect => 'commit',
        callback => sub {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
            $self->status_message('Allocation locks released, process complete');
        }
    );

    return 1;
}
    
1;
