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
                 ],
    doc => 'A reallocate command to free up disk space',
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
    unless ($self->allocator->reallocate($self->kilobytes_requested)) {
        $self->error_message('Failed to reallocate disk space');
        $self->delete;
        return;
    }
    my $gsc_disk_allocation = $self->gsc_disk_allocation;
    $gsc_disk_allocation->kilobytes_requested($self->kilobytes_requested);
    return 1;
}

1;
