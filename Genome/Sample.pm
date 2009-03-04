
package Genome::Sample; 

# Adaptor for GSC::Organism::Sample

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::Sample {
    table_name => "
(
select 
    d.*,  
    s.cell_type,    
    s.full_name,    
    s.organ_name,    
    s.organism_sample_id, 
    s.sample_name,    
    s.sample_type,    
    s.source_id,    
    s.source_type,    
    s.tissue_label,    
    s.tissue_name,
    o.taxon_id
from (
	select sample_name
	from solexa_lane_summary\@dw
	union
	select sample_name
	from run_region_454\@dw
	union
	select incoming_dna_name
	from run_region_454\@dw
	where sample_name is null
) a
join dna\@oltp d on d.dna_name = a.sample_name
left join organism_sample\@dw s on a.sample_name = s.sample_name
left join (
	dna_resource\@oltp dr 
	join entity_attribute_value\@oltp eav		
		on eav.entity_id = dr.dr_id
		and eav.type_name = 'dna'
		and eav.attribute_name = 'org id'	
	join organism_taxon\@dw o 
		on o.legacy_org_id = eav.value
) on dr.dna_resource_prefix = substr(dna_name,0,4)	
) sample ",
    id_by => [
            #organism_sample_id            => { is => 'Text', len => 10 },
            id                          => { is => 'Number', column_name => 'DNA_ID' },
    ],
    has => [
            name                        => { is => 'Text',     len => 64, column_name => 'DNA_NAME' }, # 'SAMPLE_NAME' }, 
    ],
    has_optional => [
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
            # The join over to organism_taxon is not working correctly
            # the query has a n extra iteration of the above table_name query
            # thrown in 
            taxon                       => { is => 'Genome::Taxon', id_by => 'taxon_id' },
            species_name                => { via => 'taxon' },
            #projects                   => {},
            organ_name                  => { is => 'Text', len => 64 }, 
            tissue_name                 => { is => 'Text', len => 64 }, 
            cell_type                   => { is => 'Text', len => 100 }, 
    ],
    has_many => [
            solexa_lanes                => { is => 'Genome::InstrumentData::Solexa', reverse_id_by => 'sample_id' },
            solexa_lane_names           => { via => 'solexa_lanes', to => 'full_name' },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

sub models
{
    my $self = shift;
    my @m = Genome::Model->get(subject_name => $self->name);
    return \@m;
    
}

1;

