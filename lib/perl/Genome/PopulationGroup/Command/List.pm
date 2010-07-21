package Genome::PopulationGroup::Command::List;

use strict;
use warnings;

use Genome;

class Genome::PopulationGroup::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::PopulationGroup'
        },
        show => { default_value => 'id,name,description' },
    ],
};

sub sub_command_sort_position { 3 }

1;

