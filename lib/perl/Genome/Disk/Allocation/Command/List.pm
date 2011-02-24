package Genome::Disk::Allocation::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Disk::Allocation::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Disk::Allocation' 
        },
        show => { default_value => 'id,absolute_path,kilobytes_requested,owner_class_name,owner_id,creation_time,reallocation_time' },
    ],
};

sub sub_command_sort_position { 4 }

1;

