package Genome::DrugGeneInteraction;

use strict;
use warnings;

use Genome;

class Genome::DrugGeneInteraction {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_gene_interaction',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Number' },
    ],
    has => [
        drug_name_id => { is => 'Text'},
        # drug => {

        # },
        gene_name_id => { is => 'Text'},
        # gene => {

        # },
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
    doc => 'Claim regarding an interaction between a drug name and a gene name',
};

1;
