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

1;

