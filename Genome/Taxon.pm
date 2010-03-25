
package Genome::Taxon; 

# Adaptor for GSC::Organism::Taxon
# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.
# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::Taxon {
    table_name => "(select t.*, species_name name from organism_taxon\@dw t) taxon",
    id_by => [
        taxon_id         => { is => 'Number', len => 10 },
    ],
    has => [
        name                            => { is => "Text", len => 99 },
        domain                          => { is => "Text",   len => 9 },
        species_name                    => { is => "Text",   len => 64 },
        strain_name                     => { is => "Text",   len => 32 },
        species_latin_name              => { is => "Text",   len => 64 },
        
        ncbi_taxon_id                   => { is => "Number", len => 10 },
        ncbi_taxon_species_name         => { is => "Text",   len => 128 },
        locus_tag                       => { is => "Text",   len => 200 },
        
        estimated_organism_genome_size  => { is => "Number", len => 12 },
        
        current_default_org_prefix      => { is => "Text",   len => 2 },
        next_amplicon_iteration         => { is => "Number", len => 8 },
        legacy_org_id                   => { is => "Number", len => 10 },
        current_genome_refseq_id        => { is => "Number", len => 15 },
    ],
    has_optional => [
        model_member                    => { is => 'Genome::Population', id_by => 'model_member_id',
                                            doc => 'the model individual or inbred group sequenced as a reference for this taxon' },
        model_member_id                 => { is => "Number", len => 10, column_name => 'MODEL_INDIVIDUAL_ORGANISM_ID' },
    ],
    has_many_optional => [
        individuals                     => { is => 'Genome::Individual', reverse_id_by => 'taxon',  
                                            doc => 'all tracked individual organisms (patients/research subjects) of this species/strain' },                         
 
        population_groups               => { is => 'Genome::PopulationGroup', reverse_id_by => 'taxon',
                                            doc => 'all defined population groups for this species/strain' },

        members                         => { is => 'Genome::Population',                                                       
                                            calculate => q|($self->individuals)|,
                                            doc => 'all individuals AND defined population groups' },


        samples                         => { is => 'Genome::Sample', is_many => 1, reverse_id_by => 'taxon',
                                            # if we had complete tracking, and it were efficient, we'd get this via populations above
                                            doc =>  'all DNA/RNA extractions from associated individuals and population groups' },
    ],
    doc => 'a species, strain, or other taxonomic unit',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

