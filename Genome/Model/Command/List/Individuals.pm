package Genome::Model::Command::List::Samples;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::List::Individuals {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Individual'
        },
        show => { default_value => 'id,sample_names' },
    ],
};

sub sub_command_sort_position { 2 }

1;

