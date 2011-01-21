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

    my $allocation = Genome::Disk::Allocation->get($self->allocation_id);
    confess 'Found no allocation with id ' . $self->allocation_id unless $allocation;

    my %params;
    $params{kilobytes_requested} = $self->kilobytes_requested if defined $self->kilobytes_requested;
    my $rv = $allocation->reallocate(%params);
    unless (defined $rv and $rv == 1) {
        confess 'Could not reallocate allocation ' . $self->allocation_id;
    }
    
    return 1;
}

1;
