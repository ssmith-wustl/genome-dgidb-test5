package Genome::Taxon; 

use strict;
use warnings;
use Genome;

class Genome::Taxon {
    is => 'Genome::Subject',
    has => [
        taxon_id => { 
            calculate => q|$self->id| 
        }, 
        domain => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'domain' ],
            is_mutable => 1,
        },
        # TODO this actually embeds the strain name, parse it away
        species_name => { 
            is => 'Text',
            calculate_from => 'name',
            calculate => q{ return $name; }, 
        },
        subject_type => { 
            is_constant => 1, 
            is_classwide => 1,
            value => 'species_name',
        },
    ],
    has_optional => [
        strain_name=> { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'strain_name' ],
            is_mutable => 1,
        },
        species_latin_name => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'species_latin_name' ],
            is_mutable => 1,
        },
        ncbi_taxon_id  => { 
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'ncbi_taxon_id' ],
            is_mutable => 1,
        },
        ncbi_taxon_species_name => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'ncbi_taxon_species_name' ],
            is_mutable => 1,
        },
        locus_tag => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'locus_tag' ],
            is_mutable => 1,
        },
        gram_stain_category => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'gram_stain_category' ],
            is_mutable => 1,
        },
        estimated_genome_size => { 
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'estimated_genome_size' ],
            is_mutable => 1,
        },
        current_default_org_prefix => { 
            is => 'Text',   
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'current_default_org_prefix' ],
            is_mutable => 1,
        },
        current_genome_refseq_id => { 
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'current_genome_refseq_id' ],
            is_mutable => 1,
        },
        model_member => { 
            is => 'Genome::Individual', 
            id_by => 'model_member_id',
            doc => 'the model individual or inbred group sequenced as a reference for this taxon' 
        },
        model_member_id => { 
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'model_member_id' ],  
            is_mutable => 1,
        },
        _legacy_org_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => '_legacy_org_id' ],
            is_mutable => 1,
        },
        _next_amplicon_iteration => { 
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => '_next_amplicon_iteration' ],
            is_mutable => 1,
        },
    ],
    has_many_optional => [
        individuals => { 
            is => 'Genome::Individual', 
            reverse_id_by => 'taxon',  
            doc => 'all tracked individual organisms (patients/research subjects) of this species/strain' 
        },                         
        population_groups => { 
            is => 'Genome::PopulationGroup', 
            reverse_id_by => 'taxon',
            doc => 'all defined population groups for this species/strain' 
        },
        members => {
            calculate => q|($self->individuals)|,
            doc => 'all individuals AND defined population groups' 
        },
        samples => { 
            is => 'Genome::Sample',
            reverse_id_by => 'taxon',
            # TODO if we had complete tracking, and it were efficient, we'd get this via populations above
            doc => 'all DNA/RNA extractions from associated individuals and population groups' },
    ],
    doc => 'a species, strain, or other taxonomic unit',
};

1;

