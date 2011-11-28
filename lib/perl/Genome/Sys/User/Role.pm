package Genome::Sys::User::Role;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Sys::User::Role {
    id_generator => '-uuid',
    table_name => 'subject.role',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        name => { is => 'Text' },
    ],
    has_many_optional => [
        user_bridges => {
            is => 'Genome::Sys::User::RoleMember',
            reverse_as => 'role',
        },
        users => {
            is => 'Genome::Sys::User',
            is_mutable => 1,
            via => 'user_bridges',
            to => 'user',
        },
    ],
};

sub __errors__ {
    my $self = shift;
    my @tags;

    my @duplicate_names = Genome::Sys::User::Role->get(
        name => $self->name,
        'id ne'  => $self->id,
    );
    if (@duplicate_names) {
        push @tags, UR::Object::Tag->create(
            type => 'invalid',
            properties => ['name'],
            desc => 'user role already exists with name ' . $self->name,
        );
    }

    return @tags;
}

sub delete {
    my $self = shift;
    my @users = $self->users;
    if (@users) {
        Carp::confess "Cannot delete user role " . $self->name .
            ", the following users use it: " . join(', ', map { $_->name } @users);
    }
    return $self->SUPER::delete(@_);
}

1;

