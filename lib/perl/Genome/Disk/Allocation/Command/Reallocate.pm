package Genome::Disk::Allocation::Command::Reallocate;

use strict;
use warnings;

use Genome;

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

    my $allocation = Genome::Disk::Allocation->get($self->allocation_id);
    unless ($allocation) {
        $self->warning_message("Found no allocation with id " . $self->allocation_id);
    }

    my $kilobytes_requested = $self->kilobytes_requested;
    unless (defined $kilobytes_requested) {
        $self->status_message("New allocation size not supplied, setting to size of data in allocated directory");
        $kilobytes_requested = Genome::Utility::FileSystem->disk_usage_for_path($allocation->absolute_path);
    }

    $self->status_message("Setting allocation " . $self->allocation_id . " kilobytes requested to $kilobytes_requested");
    $allocation->kilobytes_requested($kilobytes_requested);
        
    return 1;
}

1;
