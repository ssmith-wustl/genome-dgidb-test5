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
    my $rv = Genome::Disk::Allocation->delete(allocation_id => $self->allocation_id);
    confess 'Could not deallocate allocation ' . $self->allocation_id unless defined $rv and $rv == 1;
    return 1;
}

    
1;
