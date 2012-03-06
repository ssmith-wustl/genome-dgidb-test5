package Genome::Disk::Command::Allocation::Unarchive;

use strict;
use warnings;
use Genome;

class Genome::Disk::Command::Allocation::Unarchive {
    is => 'Command::V2',
    has => [
        allocations => {
            is => 'Genome::Disk::Allocation',
            is_many => 1,
            shell_args_position => 1,
            doc => 'allocations to be unarchived',
        },
    ],
    doc => 'unarchives the given allocations',
};

sub help_detail {
    return 'unarchives the given allocations, moving them from tape back onto the filesystem';
}

sub help_brief {
    return 'unarchives the given allocations';
}

sub execute {
    my $self = shift;
    Carp::confess "Unarchiving is not yet fully supported";
    $self->status_message("Starting unarchive command...");

    for my $allocation ($self->allocations) {
        $self->debug_message("Unarchiving allocation " . $allocation->id);
        my $rv = eval { $allocation->unarchive };
        if ($rv or $@) {
            my $error = $@;
            my $msg = "Could not unarchive alloation " . $allocation->id;
            $msg .= ", reason: $error" if $error;
            Carp::confess $msg;
        }
        $self->debug_message("Finished unarchiving allocation " . $allocation->id);
    }

    $self->status_message("Done unarchiving, exiting...");
    return 1;
}

1;

