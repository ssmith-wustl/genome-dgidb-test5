package Genome::Task::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Task::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Task' 
        },
        show => { default_value => 'id,command_class,status,user_id,time_submitted,time_started,time_finished' },
    ],
    doc => 'list tasks',
};

sub sub_command_sort_position { 3 }

1;
