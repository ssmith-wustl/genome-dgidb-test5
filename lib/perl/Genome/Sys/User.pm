package Genome::Sys::User;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Sys::User {
    is => 'Genome::Searchable',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    table_name => 'genome_sys_user',
    id_by => [
        email => { is => 'Text' },
    ],
    has_optional => [
        name => { is => 'Text' },
        username => {
            calculate_from => ['email'],
            calculate => sub { 
                my ($e) = @_;
                my ($u) = $e =~ /(.+)\@/; 
                return $u;
            }
        }
    ],
    has_many_optional => [
        project_parts => { is => 'Genome::ProjectPart', reverse_as => 'entity', is_mutable => 1, },
        projects => { is => 'Genome::Project', via => 'project_parts', to => 'project', is_mutable => 1, },
        project_names => { is => 'Text', via => 'projects', to => 'name', },
        user_role_bridges => {
            is => 'Genome::Sys::User::RoleMember',
            reverse_as => 'user',
        },
        user_roles => {
            is => 'Genome::Sys::User::Role',
            is_mutable => 1,
            via => 'user_role_bridges',
            to => 'role',
        },
    ],
};

sub add_role {
    my ($self, $role) = @_;
    my $bridge = Genome::Sys::User::RoleMember->create(
        user => $self,
        role => $role,
    );
    unless ($bridge) {
        Carp::confess "Could not create user role bridge entity!";
    }
    return 1;
}

sub fix_params_and_get {
    my ($class, @p) = @_;
    my %p;
    if (scalar(@p) == 1) {
        my $key = $p[0];
        $p{'email'} = $key;
    }
    else {
        %p = @p;
    }

    if (defined($p{'email'}) 
        && $p{'email'} !~ /\@/) {
        my $old = $p{'email'};
        my $new = join('@',$p{'email'},Genome::Config::domain());
        warn "Trying to get() for '$old' - assuming you meant '$new'";
        $p{'email'} = $new;
    }

    return $class->SUPER::get(%p);
}

sub __errors__ {
    my $self = shift;
    my @tags;

    my @duplicates = Genome::Sys::User->get(
        email => $self->email,
        'id not' => $self->id,
    );
    if (@duplicates) {
        push @tags, UR::Object::Tag->create(
            type => 'invalid',
            properties => ['email'],
            desc => 'user already exists with email ' . $self->email,
        );
    }

    return @tags;
}

sub delete {
    my $self = shift;

    for my $bridge ($self->user_role_bridges) {
        my $role_name = $bridge->role->name;
        my $user_name = $self->name;
        my $rv = $bridge->delete;
        unless ($rv) {
            Carp::confess "Could not delete bridge object between user $user_name and role $role_name";
        }
    }

    return $self->SUPER::delete(@_);
}

1;
