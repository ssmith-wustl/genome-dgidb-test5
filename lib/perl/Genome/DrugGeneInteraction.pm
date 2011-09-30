package Genome::DrugGeneInteraction;

use strict;
use warnings;

use Genome;

class Genome::DrugGeneInteraction {
    table_name => 'drug_gene_interaction',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Number' },
    ],
    has => [
        drug_name => { is => 'Text'},
        # drug => {

        # },
        # gene => {

        # },
        gene_name => { is => 'Text'},
        nomenclature => { is => 'Text'},
        source_db_name => { is => 'Text'},
        source_db_version => { is => 'Text'},
        interaction_type => { is => 'Text'}, 
        description => { is => 'Text' },
        drug_gene_interaction_attributes => {
            calculate_from => ['id'],
            calculate => q|
                my @drug_gene_interaction_attributes = Genome::DrugGeneInteractionAttribute->get(id => $id);
                return @drug_gene_interaction_attributes;
            |,
        },
    ],
};

1;
