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
    is => 'Genome::Measurable',
    table_name => 'GSC.ORGANISM_INDIVIDUAL',
    id_by => [
        individual_id => { is => 'Number', len => 10, column_name => 'ORGANISM_ID' },
    ],
    has => [
        name => { is => 'Text', len => 64, column_name => 'FULL_NAME', },
        taxon => { is => 'Genome::Taxon', id_by => 'taxon_id', },
        species_name    => { via => 'taxon' },
        description => { is => 'Text', is_optional => 1, len => 500, },
        subject_type => { is => 'Text', is_constant => 1, value => 'organism individual', column_name => '', },
    ],
    has_optional => [
        father  => { is => 'Genome::Individual', id_by => 'father_id' },
        father_name => { via => 'father', to => 'name' },
        mother  => { is => 'Genome::Individual', id_by => 'mother_id' },
        mother_name => { via => 'mother', to => 'name' },
        upn => { 
            is => 'Text', 
            column_name => 'NAME',
            doc => 'fully qualified internal name for the patient', 
        },
        common_name     => { 
            is => 'Text',
            len => 10,
            doc => 'a name like "aml1" for the patient, by which the patient is commonly referred-to in the lab' 
        },
        gender          => { 
            is => 'Text',
            len => 16,
            doc => 'when the gender of the individual is known, this value is set to male/female/...' 
        },
        ethnicity       => { 
            is => 'Text',
            len => 64,
            doc => 'the "ethnicity" of the individual, Hispanic/Non-Hispanic/...'
        },
        race            => { 
            is => 'Text',
            len => 64,
            doc => 'the "race" of the individual, African American/Caucasian/...'
        },
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
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    return $_[0]->name.' ('.$_[0]->id.')';
}

1;

