# bdericks: Taxon is currently a required parameter of population groups due to the 
# GSC.POPULATION_GROUP table this class is based on (which is nonnullable). The docs
# seem to indicate that a population grouping can be arbitrary, which would require
# that the taxon be defined as something useless. Can we just remove taxon entirely?

package Genome::PopulationGroup;

use strict;
use warnings;

use Genome;

class Genome::PopulationGroup {
    is => 'Genome::Subject',
    has => [
        subject_type => { 
            is => 'Text', 
            is_constant => 1, 
            value => 'population group',
        },
        taxon_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'taxon_id' ],
            is_mutable => 1,
        },
        taxon => { 
            is => 'Genome::Taxon', 
            id_by => 'taxon_id', 
        },
        species_name => { via => 'taxon' },
    ],
    has_many => [
        member_links => { 
            is => 'Genome::PopulationGroup::Member', 
            reverse_id_by => 'population_group' 
        },
        members => { 
            is => 'Genome::Individual', 
            via => 'member_links', 
            to => 'member' 
        },
        samples => { 
            is => 'Genome::Sample', 
            reverse_id_by => 'source',
        },
        sample_names => {
            via => 'samples',
            to => 'name',
        },
    ],
    doc => 'an defined, possibly arbitrary, group of individual organisms',
};

sub common_name { # not in the table, but exepected by views
    return $_[0]->name;
}

1;

