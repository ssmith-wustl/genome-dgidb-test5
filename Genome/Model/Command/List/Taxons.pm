package Genome::Model::Command::List::Taxons;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::List::Taxons {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Taxon' 
        },
        show => { default_value => 'taxon_id,species_name' },
    ],
};

sub sub_command_sort_position { 4 }

1;

