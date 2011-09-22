package Genome::DrugGeneInteractionAttribute;

use strict;
use warnings;

use Genome;

class Genome::DrugGeneInteractionAttribute {
    table_name => 'drug_gene_interaction_action',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        interaction_id => { 
            is => 'integer',
            column_name => 'id',    
        },
        name => { is => 'varchar' },
        value => { is => 'varchar' },
    ],
};

1;
