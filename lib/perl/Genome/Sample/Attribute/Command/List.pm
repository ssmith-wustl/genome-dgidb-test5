package Genome::Sample::Attribute::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Sample::Attribute::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Sample::Attribute' 
        },
        show => { default_value => 'sample_id,common_name,sample_name,nomenclature,name,value' },
    ],
};

sub sub_command_sort_position { 4 }

1;

