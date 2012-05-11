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
            doc => 'allocations that are to be set as unarchivable, resolved via Command::V2',
        },
        paths => {
            is => 'Text',
            doc => 'comma delimited list of paths, an attempt will be made to resolve them to allocations',
        },
        reason => {
            is => 'Text',
            doc => 'reason for wanting to set these allocations/paths as unarchivable',
        },
    ],
};

sub help_detail { 
    return 'Given allocations and paths are set as unarchviable. Any paths that are given are resolved ' .
        'to allocations if possible, otherwise a warning is emitted. Allocations are that marked this way ' .
        'will not be migrated to archive tape';
}
sub help_brief { return 'given allocations and paths are set as unarchivable' };
sub help_synopsis { return help_brief() . "\n" };

sub execute {
    my $self = shift;
    for my $allocation ($self->_resolve_allocations_from_paths, $self->allocations) {
        next if !$allocation->archivable;
        $allocation->archivable(0, $self->reason);
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

