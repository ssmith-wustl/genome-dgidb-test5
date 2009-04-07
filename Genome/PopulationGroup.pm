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
    is => 'Genome::SampleSource',
    has_many => [
        member_links        => { is => 'Genome::PopulationGroup::Member', reverse_id_by => 'population_group' },
        members             => { via => 'member_links', to => 'member' },
    ],
    doc => 'an defined, possibly arbitrary, group of individual organisms',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

