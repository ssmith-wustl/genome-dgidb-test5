package Genome::Disk::Command::Allocation::Preserve;

use strict;
use warnings;
use Genome;

class Genome::Disk::Command::Allocation::Preserve {
    is => 'Command::V2',
    has => [
        allocations => {
            is => 'Genome::Disk::Allocation',
            is_many => 1,
            shell_args_position => 1,
            doc => 'allocations to be preserved',
        },
    ],
    doc => 'preserves the given allocations',
};

sub help_detail {
    return 'preserves the given allocations, preventing them from being modified or deleted';
}
sub help_brief { return help_detail() }

sub _is_hidden_in_docs {
    return !Genome::Sys->current_user_is_admin;
}

sub execute {
    my $self = shift;
    $self->status_message("Starting preservation command!");

    for my $allocation ($self->allocations) {
        $self->debug_message("Preserving allocation " . $allocation->id);
        my $rv = $allocation->preserved(1);
        unless ($rv) {
            Carp::confess "Could not preserve allocation " . $allocation->id;
        }
        $self->debug_message("Finished preserving allocation " . $allocation->id);
    }

    $self->status_message("Done preserving, exiting");
    return 1;
}

1;

