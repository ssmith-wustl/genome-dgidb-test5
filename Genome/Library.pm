
package Genome::Library; 

# Adaptor for GSC::Organism::Sample

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::Library {
    table_name => "(
            select a.*, l.dna_id library_id, s.dna_id sample_id, o.taxon_id
            from (
                    select library_name, sample_name
                    from solexa_lane_summary\@dw
                    union
                    select library_name, sample_name
                    from run_region_454\@dw
            ) a
            join dna\@oltp l on l.dna_name = a.library_name
            join dna\@oltp s on s.dna_name = a.sample_name
            left join (
                    dna_resource\@oltp dr 
                    join entity_attribute_value\@oltp eav		
                            on eav.entity_id = dr.dr_id
                            and eav.type_name = 'dna'
                            and eav.attribute_name = 'org id'	
                    join organism_taxon\@dw o 
                            on o.legacy_org_id = eav.value
            ) on dr.dna_resource_prefix = substr(l.dna_name,0,4)	
        ) library ",
    id_by => [
        id                  => { is => 'Number', column_name => 'LIBRARY_ID' },
    ],
    has => [
        name                => { is => 'Text',     len => 64, column_name => 'LIBRARY_NAME' },
    ],
    has_optional => [
        sample              => { is => 'Genome::Sample', id_by => 'sample_id' },
        taxon               => { is => 'Genome::Taxon', id_by => 'taxon_id' },
        species_name        => { via => 'taxon' },
    ],
    has_many => [
        #solexa_lanes        => { is => 'Genome::InstrumentData::Solexa', reverse_id_by => 'library' },
        #solexa_lane_names   => { via => 'solexa_lanes', to => 'full_name' },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

