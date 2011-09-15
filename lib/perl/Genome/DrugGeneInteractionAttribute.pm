package Genome::DrugGeneInteractionAttribute;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::DrugGeneInteractionAttribute {
    table_name => 'drug_gene_interaction_action',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'integer' },
        name => { is => 'varchar' },
        value => { is => 'varchar' },
    ],
};

1;
