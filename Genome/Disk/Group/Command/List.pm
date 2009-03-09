package Genome::Disk::Group::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Disk::Group::Command::List {
    is => 'UR::Object::Command::List',
    has => [
            subject_class_name  => {
                                    is_constant => 1,
                                    value => 'Genome::Disk::Group',
                                },
            show => { default_value => 'disk_group_name,dg_id,subdirectory,permissions,sticky' },
    ],
};

sub sub_command_sort_position { 4 }

1;

