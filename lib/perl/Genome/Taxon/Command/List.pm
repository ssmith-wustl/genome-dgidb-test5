package Genome::Taxon::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Taxon::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Taxon' 
        },
        show => { default_value => 'id,name,species_latin_name,ncbi_taxon_id,locus_tag,domain' },
    ],
};

sub sub_command_sort_position { 4 }

1;

