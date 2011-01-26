package Genome::Disk::Allocation::Command::Deallocate;

use strict;
use warnings;

use Genome;

class Genome::Disk::Allocation::Command::Deallocate {
    is => 'Genome::Disk::Allocation::Command',
    has => [
            allocator_id => {
                             is => 'Number',
                             doc => 'The id for the allocator event',
                         },
        ],
    has_optional => [
                     deallocator_id => {
                                      is => 'Number',
                                      doc => 'The id for the deallocator pse',
                                  },
                     deallocator => {
                                     calculate_from => 'deallocator_id',
                                     calculate => q|
                                         return GSC::PSE::DeallocateDiskSpace->get($deallocator_id);
                                     |,
                                 },
    ],
    doc => 'A deallocate command to free up disk space',
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
    unless ($self->deallocator_id) {
        my $deallocate_pse = $self->allocator->deallocate;
        unless ($deallocate_pse) {
            $self->error_message('Failed to deallocate disk space');
            $self->delete;
            return;
        }
        $self->deallocator_id($deallocate_pse->pse_id);
    }
    unless ($self->deallocator) {
        $self->error_message('Deallocator not found for deallocator id: '. $self->deallocator_id);
        $self->delete;
        return;
    }
    return $self;
}

sub execute {
    my $self = shift;
    
    my $deallocator = $self->deallocator;
    
    $self->status_message('Deallocate PSE id: '. $deallocator->pse_id);
        
    my $rv;

    if ($self->local_confirm) {
        $rv = $self->confirm_scheduled_pse($deallocator);
    } else {
        $rv = $self->wait_for_pse_to_confirm(pse => $deallocator);
    }
    
    # Commit here to free up a DB lock we'll be holding if we executed the 
    # deallocation PSE via confirm_scheduled_pse().  
    UR::Context->commit();

    $self->status_message('Committed and released lock');

    unless ($rv) {
        $self->error_message('Failed to confirm pse '. $self->deallocator_id);
        return;
    }
   
    my $apipe_allocation = Genome::Disk::AllocationNew->get($self->allocator_id);
    if ($apipe_allocation) {
        $apipe_allocation->delete;
    }

    return 1;
}

1;
