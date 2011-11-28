package Genome::Sys::User::RoleMember;

use strict;
use warnings;

use Genome;

class Genome::Sys::User::RoleMember {
    table_name => 'subject.role_member',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        user_email => { is => 'Text' },
        role_id => { is => 'Text' },
    ],
    has => [
        user => { 
            is => 'Genome::Sys::User',
            id_by => 'user_email',
        },
        role => {
            is => 'Genome::Sys::User::Role',
            id_by => 'role_id',
        },
    ],
};

sub __errors__ {
    my $self = shift;
    my @tags;

    my @duplicates = eval { 
        Genome::Sys::User::RoleMember->get(
            role => $self->role,
            user => $self->user,
        )
    };
    my $error = $@;
    if ($error) {
        # Make a more human-readable error message in the case where a duplicate bridge entity already exists
        if ($error =~  /An object of type Genome::Sys::User::RoleMember already exists with id/) {
            $error = "Cannot add role " . $self->role->name . " to user " . $self->user->name . ", that user already has this role!",
        }

        push @tags, UR::Object::Tag->create(
            type => 'invalid',
            properties => ['role', 'user'],
            desc => $error,
        );
    }

    return @tags;
}

1;

