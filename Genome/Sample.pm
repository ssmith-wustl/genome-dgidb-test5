
package Genome::Sample; 

# Adaptor for GSC::Organism::Sample

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::Sample {
    table_name => q|
(
    select 
        --temporary
        d.dna_id                id,
        a.sample_name           name,
        o.taxon_id,
        
        --futuristic
        s.organism_sample_id    id_new,
        s.full_name             name_new,
        s.taxon_id              taxon_id_new,
        
        --common
        s.sample_name           extraction_label,
        s.sample_type           extraction_type,
        s.description           extraction_desc,
        s.cell_type,        
        s.tissue_label,    
        s.tissue_name           tissue_desc,
        s.organ_name,    
        s.source_id,    
        s.source_type
    from (
        select sample_name
        from solexa_lane_summary@dw
        union
        select sample_name
        from run_region_454@dw
        union
        select incoming_dna_name
        from run_region_454@dw
        where sample_name is null
    ) a
    join dna@oltp d on d.dna_name = a.sample_name
    left join organism_sample@dw s on d.dna_id = s.organism_sample_id
    left join (
        dna_resource@oltp dr 
        join entity_attribute_value@oltp eav        
            on eav.entity_id = dr.dr_id
            and eav.type_name = 'dna'
            and eav.attribute_name = 'org id'   
        join organism_taxon@dw o 
            on o.legacy_org_id = eav.value
    ) on dr.dna_resource_prefix = substr(dna_name,0,4)
) sample
|,
    id_by => [
        id                          => { is => 'Number',
                                        doc => 'the numeric ID for the specimen in both the LIMS and the analysis system' },
    ],
    has => [
        name                        => { is => 'Text',     len => 64, 
        								doc => 'the fully qualified name for the sample (the "DNA NAME" in LIMS for both DNA and RNA)' },
    ],
    has_optional => [	
        extraction_label            => { is => 'Text', 
                                        doc => 'identifies the specimen sent from the laboratory which extracted DNA/RNA' },
                
        extraction_type             => { is => 'Text', 
                                        doc => 'either "genomic dna" or "rna" in most cases' },
                
        extraction_desc             => { is => 'Text', 
                                        doc => 'notes specified when the specimen entered this site' },
                
        cell_type                   => { is => 'Text', len => 100,
                                        doc => 'typically "primary"' },

        tissue_label	            => { is => 'Text', 
                                        doc => 'identifies/labels the original tissue sample from which this extraction was made' },
        								
        tissue_desc                 => { is => 'Text', len => 64, 
                                        doc => 'describes the original tissue sample' },
        
        organ_name                  => { is => 'Text', len => 64, 
                                        doc => 'the name of the organ from which the sample was taken' }, 
        
        # these are optional only b/c our data is not fully back-filled
        source                      => { is => 'Genome::SampleSource', id_by => 'source_id',
                                        doc => 'The patient/individual organism from which the sample was taken, or the population for pooled samples.' },
        
        source_type                 => { is => 'Text',
                                        doc => 'either "organism individual" for individual patients, or "population group" for cross-individual samples' },
        
        source_name                 => { via => 'source', to => 'name' },
        
        taxon                       => { is => 'Genome::Taxon', id_by => 'taxon_id', 
										doc => 'the taxon of the sample\'s source' },
        
        species_name                => { via => 'taxon', to => 'species_name', 
        								doc => 'the name of the species of the sample source\'s taxonomic category' },
                                        
        _id_new                     => { column_name => 'ID_NEW' },
        _name_new                   => { column_name => 'NAME_NEW' },
        _taxon_id_new               => { column_name => 'TAXON_ID_NEW' },
    ],
    has_many => [
        libraries                   => { is => 'Genome::Library', reverse_id_by => 'sample' },
        solexa_lanes                => { is => 'Genome::InstrumentData::Solexa', reverse_id_by => 'sample' },
        solexa_lane_names           => { via => 'solexa_lanes', to => 'full_name' },
    ],
    doc         => 'a single specimen of DNA or RNA extracted from some tissue sample',
    data_source => 'Genome::DataSource::GMSchema',
};

sub sample_type {
    shift->extraction_type(@_);
}

sub models {
    my $self = shift;
    my @m = Genome::Model->get(subject_name => $self->name);
    return @m;
}

1;

