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
            default_value => 'mount_path,disk_group_names,total_kb,usable_unallocated_kb' 
        },
    ],
};

sub sub_command_sort_position { 4 }

1;

