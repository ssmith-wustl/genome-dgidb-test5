
package Genome::PopulationGroup;

# Adaptor for GSC::PopulationGroup

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::PopulationGroup {
    table_name => '(select * from population_group@dw) population_group',
    id_by => [
        pg_id           => { is => 'Text', len => 10 },
    ],
    has => [
        name            => { is => 'Text',     len => 64, column_name => 'SAMPLE_NAME' }, 
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

