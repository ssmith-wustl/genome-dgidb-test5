package Genome::Individual;

# Adaptor for GSC::Organism::Individual

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

use Genome;

class Genome::Individual {
    is => 'Genome::SampleSource',
    has_optional => [
        father  => { is => 'Genome::Individual', id_by => 'father_id' },
        mother  => { is => 'Genome::Individual', id_by => 'mother_id' },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

