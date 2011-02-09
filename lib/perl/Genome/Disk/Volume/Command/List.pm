package Genome::Disk::Volume::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Disk::Volume::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1,
            value => 'Genome::Disk::Volume',
        },
        show => { 
            default_value => 'mount_path,total_kb,unallocated_kb,disk_group_names' 
        },
    ],
};

sub sub_command_sort_position { 4 }

1;

