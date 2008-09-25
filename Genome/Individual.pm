
package Genome::Individual;

# Adaptor for GSC::Organism::Sample

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
        samples         => { is => 'Genome::Sample', reverse_id_by => 'source_individual' },
        sample_names    => { via => 'samples', to => 'name' },
    ],
    has => [
        name            => { is => 'Text',     len => 64, column_name => 'SAMPLE_NAME' }, 
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

