package Genome::DrugGeneInteractionAttribute;

use strict;
use warnings;

use Genome;

class Genome::DrugGeneInteractionAttribute {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_gene_interaction_attribute',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        interaction_id => { is => 'Number'},
        drug_gene_interaction => { is => 'Genome::DrugGeneInteraction', id_by => 'interaction_id', constraint_name => 'drug_gene_interaction_attribute_interaction_id_fkey' },
        name           => { is => 'Text' },
        value          => { is => 'Text' },
    ],
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    doc => 'Claim regarding an attribute of a drug gene interaction claim',
};

1;
