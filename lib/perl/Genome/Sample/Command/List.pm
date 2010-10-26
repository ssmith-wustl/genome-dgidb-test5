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
        show => { default_value => 'id,name,species_name,patient_common_name,common_name,tissue_label,tissue_desc,extraction_type,extraction_label,extraction_desc' },
    ],
};

sub sub_command_sort_position { 4 }

1;

