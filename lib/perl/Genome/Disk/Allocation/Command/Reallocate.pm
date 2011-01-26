package Genome::Disk::Allocation::Command::Reallocate;

use strict;
use warnings;

use Genome;

class Genome::Disk::Allocation::Command::Reallocate {
    is => 'Genome::Disk::Allocation::Command',
    has => [
            allocator_id => {
                             is => 'Number',
                             doc => 'The id for the allocator event',
                         },
        ],
    has_optional => [
                     kilobytes_requested => {
                                             is => 'Number',
                                             doc => 'The disk space allocated in kilobytes',
                                         },
                     reallocator_id => {
                                        is => 'Number',
                                        doc => 'The id for the reallocator pse',
                                  },
                     reallocator => {
                                     calculate_from => 'reallocator_id',
                                     calculate => q|
                                         return GSC::PSE::ReallocateDiskSpace->get($reallocator_id);
                                     |,
                                 },
    ],
    doc => 'A reallocate command to update the allocated disk space',
};


sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    unless ($self) {
        return;
    }
    unless ($self->allocator_id) {
        $self->error_message('Allocator id required!  See --help.');
        $self->delete;
        return;
    }
    unless ($self->allocator) {
        $self->error_message('GSC::PSE::AllocateDiskSpace not found for id '. $self->allocator_id);
        $self->delete;
        return;
    }
    unless ($self->reallocator_id) {
        my $reallocate_pse = $self->allocator->reallocate($self->kilobytes_requested);
        unless ($reallocate_pse) {
            $self->error_message('Failed to reallocate disk space');
            $self->delete;
            return;
        }
        $self->reallocator_id($reallocate_pse->pse_id);
    }
    unless ($self->reallocator) {
        $self->error_message('Reallocator not found for reallocator id: '. $self->reallocator_id);
        $self->delete;
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;
    my $reallocator = $self->reallocator;
    $self->status_message('Reallocate PSE id: '. $self->reallocator_id);
    my $rv;
    if ($self->local_confirm) {
        $rv = $self->confirm_scheduled_pse($reallocator);
    } else {
        $rv = $self->wait_for_pse_to_confirm(pse => $reallocator);
    }
    
    # Commit here to free up a DB lock we'll be holding if we executed the 
    # reallocation PSE via confirm_scheduled_pse().
    UR::Context->commit();
    
    $self->status_message('Committed and released lock');
    
    unless ($rv) {
        $self->error_message('Failed to confirm pse '. $self->reallocator_id);
        return;
    }

    # update apipe schema
    my $apipe_allocation = Genome::Disk::AllocationNew->get($self->allocator_id);
    if ($apipe_allocation) {
        $apipe_allocation->kilobytes_requested($self->disk_allocation->kilobytes_requested);
    }

    return 1;
}

1;
