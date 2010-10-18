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
    table_name => 'GSC.ORGANISM_INDIVIDUAL individual',
    id_by => [
        individual_id => { is => 'Number', len => 10, column_name => 'ORGANISM_ID' },
    ],
    has_optional => [
        father  => { is => 'Genome::Individual', id_by => 'father_id' },
        mother  => { is => 'Genome::Individual', id_by => 'mother_id' },
        
        father_name => { via => 'father', to => 'name' },
        mother_name => { via => 'mother', to => 'name' },
        
        name            => { is => 'Text',
                            doc => 'fully qualified internal/system name for the patient (prefix used in DNA naming)', },

        upn             => { is => 'Text', 
                            column_name => 'NAME',
                            doc => 'fully qualified internal name for the patient', },

        common_name     => { is => 'Text',
                            doc => 'a name like "aml1" for the patient, by which the patient is commonly referred-to in the lab' },

        gender          => { is => 'Text',
                            doc => 'when the gender of the individual is known, this value is set to male/female/...' },
        ethnicity       => { is => 'Text',
                            doc => 'the "ethnicity" of the individual, Hispanic/Non-Hispanic/...'},
        race            => { is => 'Text',
                            doc => 'the "race" of the individual, African American/Caucasian/...'},
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

