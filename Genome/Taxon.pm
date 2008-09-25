
package Genome::Taxon; 

# Adaptor for GSC::Organism::Taxon
# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.
# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

class Genome::Taxon {
    table_name => '(select * from organism_taxon@dw) taxon',
    id_by => [
            taxon_id         => { is => 'Number', len => 10 },
    ],
    has => [
        current_default_org_prefix      => { is => "Text",   len => 2 },
        current_genome_refseq_id        => { is => "Number", len => 15 },
        domain                          => { is => "Text",   len => 9 },
        estimated_organism_genome_size  => { is => "Number", len => 12 },
        legacy_org_id                   => { is => "Number", len => 10 },
        locus_id                        => { is => "Text",   len => 200 },
        model_individual_organism_id    => { is => "Number", len => 10 },
        ncbi_taxon_id                   => { is => "Number", len => 10 },
        ncbi_taxon_species_name         => { is => "Text",   len => 128 },
        next_amplicon_iteration         => { is => "Number", len => 8 },
        species_latin_name              => { is => "Text",   len => 64 },
        species_name                    => { is => "Text",   len => 64 },
        strain_name                     => { is => "Text",   len => 32 },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

