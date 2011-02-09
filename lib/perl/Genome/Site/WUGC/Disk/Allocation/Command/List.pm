package Genome::Site::WUGC::Disk::Allocation::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::Disk::Allocation::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Site::WUGC::Disk::Allocation' 
        },
        show => { default_value => 'absolute_path,kilobytes_requested,kilobytes_used,allocator_id,owner_class_name,owner_id' },
    ],
};

sub sub_command_sort_position { 4 }

1;

