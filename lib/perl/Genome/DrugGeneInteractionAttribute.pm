package Genome::DrugGeneInteractionAttribute;

use strict;
use warnings;

use Genome;

class Genome::DrugGeneInteractionAttribute {
    table_name => 'drug_gene_interaction_attribute',
    id_by => [
        interaction_id => { is => 'Number'},
        name           => { is => 'Text' },
        value          => { is => 'Text' },
    ],
    has => [
        drug_gene_interaction => { is => 'Genome::DrugGeneInteraction', id_by => 'interaction_id', constraint_name => 'drug_gene_interaction_attribute_interaction_id_fkey' },
    ],
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
};

1;
