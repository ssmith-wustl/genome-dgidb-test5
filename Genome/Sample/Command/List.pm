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
        show => { default_value => 'id,name,species_name,tissue_label,extraction_label,extraction_type,tissue_desc,extraction_desc,source_name' },
    ],
};

sub sub_command_sort_position { 4 }

1;

