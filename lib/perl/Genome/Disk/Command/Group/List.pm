package Genome::Disk::Command::Group::List;

use strict;
use warnings;

use Genome;

class Genome::Disk::Command::Group::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1,
            value => 'Genome::Disk::Group',
        },
        show => { 
            default_value => 'disk_group_name,dg_id,user_name,group_name,subdirectory' 
        },
        filter => { 
            default_value => 'user_name=apipe' 
        },
    ],
    doc => 'Lists Genome::Disk::Group objects',
};

1;

