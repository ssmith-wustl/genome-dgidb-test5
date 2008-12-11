
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
            select d.*, o.taxon_id
            from (
                    select library_name
                    from solexa_lane_summary\@dw
                    union
                    select library_name
                    from run_region_454\@dw
            ) a
            join dna\@oltp d on d.dna_name = a.library_name
            left join (
                    dna_resource\@oltp dr 
                    join entity_attribute_value\@oltp eav		
                            on eav.entity_id = dr.dr_id
                            and eav.type_name = 'dna'
                            and eav.attribute_name = 'org id'	
                    join organism_taxon\@dw o 
                            on o.legacy_org_id = eav.value
            ) on dr.dna_resource_prefix = substr(dna_name,0,4)	
        ) library ",
    id_by => [
            #organism_sample_id            => { is => 'Text', len => 10 },
            id                          => { is => 'Number', column_name => 'DNA_ID' },
    ],
    has => [
            name                        => { is => 'Text',     len => 64, column_name => 'DNA_NAME' }, # 'LIBRARY_NAME' }, 
    ],
    has_optional => [
            taxon                       => { is => 'Genome::Taxon', id_by => 'taxon_id' },
            species_name                => { via => 'taxon' },
            #projects                   => {},
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

