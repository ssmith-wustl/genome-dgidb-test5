
package Genome::Individual;

# Adaptor for GSC::Organism::Individual

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::Individual {
    table_name => '(select * from organism_individual@dw) individual',
    id_by => [
        organism_id     => { is => 'Text', len => 10 },
    ],
    has_many_optional => [
        samples         => { is => 'Genome::Sample', reverse_id_by => 'source_id' },
        sample_names    => { via => 'samples', to => 'sample_name' },
    ],
    has => [
        name            => { is => 'Text', len => 64 },
        taxon_id        => { is => 'Text', len => 10 },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

