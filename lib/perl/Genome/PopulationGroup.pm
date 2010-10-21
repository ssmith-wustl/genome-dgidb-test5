package Genome::PopulationGroup;

# Adaptor for GSC::PopulationGroup

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

use Genome;

class Genome::PopulationGroup {
    is => 'Genome::Measurable',
    table_name => 'GSC.POPULATION_GROUP',
    id_by => [
        individual_id => { is => 'Number', len => 10, column_name => 'PG_ID' },
    ],
    has => [
        name => { is => 'Text', len => 64, },
        subject_type => { is => 'Text', is_constant => 1, value => 'population group', column_name => '', },
        taxon => { is => 'Genome::Taxon', id_by => 'taxon_id', },
        species_name => { via => 'taxon' },
        description => { is => 'Text', is_optional => 1, },
    ],
    has_many => [
        member_links        => { is => 'Genome::PopulationGroup::Member', reverse_id_by => 'population_group' },
        members             => { is => 'Genome::Individual', via => 'member_links', to => 'member' },
        samples => { 
            is => 'Genome::Sample', 
            is_many => 1,
            reverse_id_by => 'source',
        },
        sample_names => {
            via => 'samples',
            to => 'name', is_many => 1,
        },
    ],
    doc => 'an defined, possibly arbitrary, group of individual organisms',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

