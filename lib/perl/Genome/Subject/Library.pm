package Genome::Subject::Library; 

use strict;
use warnings;
use Genome;

class Genome::Subject::Library {
    is => 'Genome::Subject', 
    has => [
        sample_id => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'sample_id' ],
            is_mutable => 1,
        },
        sample => { 
            is => 'Genome::Subject::Sample', 
            id_by => 'sample_id',
        },
        sample_name => {
            via => 'sample',
            to => 'name',
        },
    ],
    has_optional => [
        taxon_id => { 
            is => 'Number', 
            via => 'sample', 
        },
        taxon => { 
            is => 'Genome::Subject::Taxon', 
            via => 'sample', 
        },
        species_name => { 
            is => 'Text', 
            via => 'taxon', 
        },
        fragment_size_range => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fragment_size_range' ],
            is_mutable => 1,
        },
        protocol_name => {
            is => 'Text',
            is_transient => 1,
        },
    ],
};

sub __display_name__ {
    return $_[0]->name.' ('.$_[0]->id.')';
}

1;

