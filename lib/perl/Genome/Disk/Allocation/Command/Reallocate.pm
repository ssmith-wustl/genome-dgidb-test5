package Genome::Disk::Allocation::Command::Reallocate;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Disk::Allocation::Command::Reallocate {
    is => 'Genome::Disk::Allocation::Command',
    has => [
        allocation_id => {
            is => 'Number',
            doc => 'ID for allocation to be resized',
        },
    ],
    has_optional => [
        kilobytes_requested => {
            is => 'Number',
            doc => 'Number of kilobytes that target allocation should reserve, if not ' .
                'provided then the current size of the allocation is used',
        },
    ],
    doc => 'This command changes the requested kilobytes for a target allocation',
};

sub help_brief {
    return 'Changes the requested kilobytes field on the target allocation';
}

sub help_synopsis { 
    return 'Changes the requested kilobytes field on the target allocation';
}

sub help_detail {
    return <<EOS
Changes the requested kilobytes field on the target allocation. If no value
is supplied to this command, the field is set to the current size of the
allocation.
EOS
}

sub execute {
    my $self = shift;
    $self->status_message('Starting reallocation process');

    # Get allocation lock and object
    my $allocation_lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/allocation_' . $self->allocation_id,
        max_try => 5,
        block_sleep => 1,
    );
    confess 'Could not get lock for allocation ' . $self->allocation_id unless defined $allocation_lock;

    my $allocation = Genome::Disk::Allocation->get($self->allocation_id);
    unless ($allocation) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Found no allocation with id ' . $self->allocation_id;
    }

    $self->status_message('Acquired allocation lock and retrieved allocation');

    # Either figure out what the allocation should be resized to or check that the given number is valid
    my $kilobytes_requested = $self->kilobytes_requested;
    if (defined $kilobytes_requested and $kilobytes_requested < 0) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Setting kilobytes requested to a negative number? Nice try.';
    }
    elsif (not defined $kilobytes_requested) {
        $self->status_message('New allocation size not supplied, setting to size of data in allocated directory');
        $kilobytes_requested = Genome::Utility::FileSystem->disk_usage_for_path($allocation->absolute_path);
        unless (defined $kilobytes_requested) {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
            confess 'Could not determine size of allocation directory ' . $allocation->absolute_path;
        }
    }
    my $diff = $kilobytes_requested - $allocation->kilobytes_requested;

    # Now acquire volume lock and get the volume
    my $modified_mount = $allocation->mount_path;
    $modified_mount =~ s/\//_/g;
    my $volume_lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/volume_' . $modified_mount,
        max_try => 5,
        block_sleep => 1,
    );
    unless (defined $volume_lock) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get lock for volume ' . $allocation->mount_path;
    }

    my $volume = Genome::Disk::Volume->get(mount_path => $allocation->mount_path);
    unless ($volume) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Could not get volume with mount path ' . $allocation->mount_path;
    }

    $self->status_message('Acquired volume lock and retrieved volume');

    # Make sure there's room for the allocation... only applies if the new allocation is bigger than the old
    unless ($volume->unallocated_kb >= $diff) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
        Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
        confess 'Not enough unallocated space on volume ' . $volume->mount_path . " to increase allocation size by $diff kb"
    }
        
    # Update allocation and volume
    $allocation->kilobytes_requested($kilobytes_requested);
    $volume->unallocated_kb($volume->unallocated_kb - $diff);

    # Release locks when the changes are committed
    $volume->add_observer(
        aspect => 'commit',
        callback => sub {
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $volume_lock);
            Genome::Utility::FileSystem->unlock_resource(resource_lock => $allocation_lock);
            $self->status_message('Locks released, process complete');
        }
    );

    return 1;
}

1;
