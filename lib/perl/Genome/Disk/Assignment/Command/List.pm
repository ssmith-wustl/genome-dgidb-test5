package Genome::Disk::Assignment::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Disk::Assignment::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1,
            value => 'Genome::Disk::Assignment',
        },
        show => { 
            default_value => 'assignment_date,disk_group_name,absolute_path,total_kb,unallocated_kb,percent_allocated' 
        },
    ],
};

sub sub_command_sort_position { 4 }

1;
