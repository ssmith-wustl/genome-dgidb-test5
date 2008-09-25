
package Genome::Sample; 

# Adaptor for GSC::Organism::Sample

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::Sample {
    table_name => '(select * from organism_sample@dw) sample',
    id_by => [
          organism_sample_id            => { is => 'Text', len => 10 },
    ],
    has => [
            name                        => { is => 'Text',     len => 64, column_name => 'SAMPLE_NAME' }, 
            source_id                   => { is => 'Number',   len => 10 },
            source_type                 => { is => 'Text',     len => 64 }, 
            source_individual           => { is => 'Genome::Individual', id_by => 'source_id' },
            source_population           => { is => 'Genome::PopulationGroup', id_by => 'source_id' },
            source                      => { is => 'Genome::Sample::Source', calculate_from => ['source_type','source_id'], 
                                            calculate => q|
                                                my $class = $source_type eq 'population group' ? 'Genome::PopulationGroup' : 'Genome::Individual';
                                                $class->get(id => $source_id, @_) 
                                            | },
            source_name                 => { via => 'source', to => 'name' },
            #projects                   => {},
    ],
    has_optional => [
            organ_name                  => { is => 'Text', len => 64 }, 
            tissue_name                 => { is => 'Text', len => 64 }, 
            cell_type                   => { is => 'Text', len => 100 }, 
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

