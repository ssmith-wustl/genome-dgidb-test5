package Genome::Disk::Allocation::Command::Deallocate;

use strict;
use warnings;

use Genome;

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

    my $allocation = Genome::Disk::Allocation->get($self->allocation_id);
    unless ($allocation) {
        Carp::confess 'Found no allocation with ID ' . $self->allocation_id;
    }

    my $path = $allocation->absolute_path;
    $allocation->add_observer(
        aspect => 'commit',
        callback => sub {
            my $rv = Genome::Utility::FileSystem->remove_directory_tree($path);
            $self->error_message("Could not remove allocation path $path");
        }
    );

    $self->status_message('Removing allocation with ID ' . $self->allocation_id);
    my $delete_rv = $allocation->delete;
    Carp::confess 'Could not remove allocation!' unless defined $delete_rv and $delete_rv;

    return 1;
}
    
1;
