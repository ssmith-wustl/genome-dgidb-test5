package Genome::SampleSource;

# Base class for Genome::Individual and Genome::PopulationGroup

use strict;
use warnings;

use Genome;

class Genome::SampleSource {
    table_name => 
        q|(
            select organism_id id,
                full_name name,
                taxon_id,
                description,
                common_name,
                'Genome::Individual' sample_source_subclass_name
            from GSC.organism_individual
            union all
            select pg_id id,
                name,
                taxon_id,
                description,
                NULL common_name,
                'Genome::PopulationGroup' sample_source_subclass_name 
            from GSC.population_group
        ) sample_source|,
    is_abstract => 1,
    subclassify_by => 'sample_source_subclass_name',
    id_by => [
        id           => { is => 'Text', len => 10 },
    ],
    has => [
        sample_source_subclass_name => { is => 'Text' },        
        name            => { is => 'Text', len => 64 },
    ],
    has_optional => [
        common_name     => { is => 'Text' },
        description     => { is => 'Text' },
        
        taxon           => { is => 'Genome::Taxon', id_by => 'taxon_id' },
        species_name    => { via => 'taxon' },
    ],
    has_many_optional => [
        samples         => { is => 'Genome::Sample', reverse_id_by => 'source' },
        sample_names    => { via => 'samples', to => 'name' },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

