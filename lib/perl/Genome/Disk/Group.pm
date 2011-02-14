package Genome::Disk::Group;

use strict;
use warnings;

class Genome::Disk::Group {
    table_name => 'DISK_GROUP',
    id_by => [
        dg_id => { is => 'Number' },
    ],
    has => [
        disk_group_name => { is => 'Text' },
        permissions => { is => 'Number' },
        sticky => { is => 'Number' },
        subdirectory => { is => 'Text' },
        unix_uid => { is => 'Number' },
        unix_gid => { is => 'Number' },
        user_name => {
            calculate_from => 'unix_uid',
            calculate => q|
                my ($user_name) = getpwuid($unix_uid);
                return $user_name;
            |,
        },
        group_name => {
            calculate_from => 'unix_gid',
            calculate => q| 
                my ($group_name) = getgrgid($unix_gid);
                return $group_name;
            |,
        },
    ],
    has_many_optional => [
        mount_paths => {
            via => 'volumes',
            to => 'mount_path',
        },
        volumes => {
            is => 'Genome::Disk::Volume',
            via => 'assignments',
            to =>  'volume',
        },
        assignments => {
            is => 'Genome::Disk::Assignment',
            reverse_id_by => 'group',
        },
    ],
    data_source => 'Genome::DataSource::Oltp',
    doc => 'Represents a disk group (eg, info_apipe), which contains any number of disk volumes',
};

1;
