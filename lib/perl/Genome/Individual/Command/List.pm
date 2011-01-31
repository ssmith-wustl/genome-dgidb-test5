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
        show => { default_value => 'id,name,upn,species_name,common_name,gender' },
    ],
};

sub sub_command_sort_position { 1 }

1;

