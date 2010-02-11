package EGAP::Organism;

use strict;
use warnings;

use EGAP;
class EGAP::Organism {
    type_name => 'organism',
    table_name => 'ORGANISM',
    id_sequence_generator_name => 'sequence_id_seq',
    id_by => [
        organism_id => { is => 'NUMBER', len => 6 },
    ],
    has => [
        gram_stain       => { is => 'VARCHAR2', len => 1, is_optional => 1 },
        locus            => { is => 'VARCHAR2', len => 20, is_optional => 1 },
        ncbi_taxonomy_id => { is => 'NUMBER', len => 8, is_optional => 1 },
        organism_name    => { is => 'VARCHAR2', len => 50 },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
