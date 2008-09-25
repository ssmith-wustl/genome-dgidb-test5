package Genome::Model::Command::List::Samples;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::List::Samples {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Sample' 
        },
        show => { default_value => 'id,name,source_type' },
    ],
};

sub sub_command_sort_position { 4 }

1;

