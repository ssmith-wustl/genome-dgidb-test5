package Genome::DiskAllocation::Command::Deallocate;

use strict;
use warnings;

use Genome;

class Genome::DiskAllocation::Command::Deallocate {
    is => 'Genome::DiskAllocation::Command',
    has => [
            allocator_id => {
                             is => 'Number',
                             doc => 'The id for the allocator event',
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
    unless ($self->gsc_disk_allocation) {
        $self->error_message('GSC::DiskAllocation not found for id '. $self->allocator_id);
        $self->delete;
        return;
    }
    return $self;
}

sub execute {
    my $self = shift;
    unless ($self->allocator->deallocate) {
        $self->error_message('Failed to deallocate disk space');
        $self->delete;
        return;
    }
    my $gsc_disk_allocation = $self->gsc_disk_allocation;
    unless ($gsc_disk_allocation->delete) {
        $self->error_message('Failed to remove GSC::DiskAllocation!');
        $self->delete;
        return;
    }
    return 1;
}

1;
