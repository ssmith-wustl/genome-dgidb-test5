package Genome::Capture::Set::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Capture::Set',
        },
        show => { default_value => 'id,barcode,name,status,description' },
    ],
};

sub sub_command_sort_position { 4 }

1;

