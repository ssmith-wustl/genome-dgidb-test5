package Genome::Sys::User::Role;

use strict;
use warnings;
use Genome;

class Genome::Sys::User::Role {
    id_generator => '-uuid',
    table_name => 'subject.role',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        name => { is => 'Text' },
        user_bridges => {
            is => 'Genome::Sys::User::RoleMember',
            is_many => 1,
            reverse_as => 'role',
        },
        users => {
            is => 'Genome::Sys::User',
            is_many => 1,
            is_mutable => 1,
            via => 'user_bridges',
            to => 'user',
        },
    ],
};

1;

