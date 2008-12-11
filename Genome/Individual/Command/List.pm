package Genome::Individual::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Individual::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Individual'
        },
        show => { default_value => 'id,name' },
    ],
};

sub sub_command_sort_position { 3 }

1;

