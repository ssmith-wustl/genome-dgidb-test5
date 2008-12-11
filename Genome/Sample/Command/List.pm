package Genome::Sample::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Sample::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Sample' 
        },
        show => { default_value => 'id,name,source_type,species_name' },
    ],
};

sub sub_command_sort_position { 4 }

1;

