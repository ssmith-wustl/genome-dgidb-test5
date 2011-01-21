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
    my $allocation = Genome::Disk::Allocation->get($self->allocation_id);
    confess 'Could not find allocation with id ' . $self->allocation_id unless $allocation;
    $allocation->delete(remove_allocation_directory => $self->remove_allocation_directory);
    return 1;
}

    
1;
