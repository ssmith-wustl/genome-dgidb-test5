package Genome::Disk::Command::Allocation::SetUnarchivable;

use strict;
use warnings;
use Genome;

class Genome::Disk::Command::Allocation::SetUnarchivable {
    is => 'Command::V2',
    has_optional => [
        allocations => {
            is => 'Genome::Disk::Allocation',
            is_many => 1,
            doc => 'Allocations that are to be set as unarchivable',
        },
        paths => {
            is => 'Text',
            doc => 'Comma delimited list of paths, an attempt will be made to resolve them to allocations',
        },
    ],
};

sub help_detail { return 'given allocations and paths are set as unarchivable' };
sub help_brief { return help_detail() };
sub help_synopsis { return help_detail() };

sub execute {
    my $self = shift;
    for my $allocation ($self->_resolve_allocations_from_paths, $self->allocations) {
        next if !$allocation->archivable;
        $allocation->archivable(0);
    }
    $self->status_message("Successfully set allocations as unarchivable");
    return 1;
}

sub _resolve_allocations_from_paths {
    my $self = shift;
    return unless $self->paths;

    my @allocations;
    for my $path (split(/,/, $self->paths)) {
        my $allocation_path = Genome::Disk::Allocation->_allocation_path_from_full_path($path);
        unless ($allocation_path) {
            $self->warning_message("No allocation found for path $path");
            next;
        }

        my $allocation = Genome::Disk::Allocation->_get_parent_allocation($allocation_path);
        unless ($allocation) {
            $self->warning_message("No allocation found for path $path");
            next;
        }
        push @allocations, $allocation;
    }
    return @allocations;
}

1;

