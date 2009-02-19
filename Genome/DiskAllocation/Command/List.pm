package Genome::DiskAllocation::Command::List;

use strict;
use warnings;

use Genome;

class Genome::DiskAllocation::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::DiskAllocation' 
        },
        show => { default_value => 'allocator_id,disk_group_name,mount_path,allocation_path,kilobytes_requested,owner_class_name,owner_id' },
    ],
};

sub sub_command_sort_position { 4 }

1;

