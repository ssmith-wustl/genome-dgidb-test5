package Genome::DrugGeneInteraction;

use strict;
use warnings;

use Genome;

class Genome::DrugGeneInteraction {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_gene_interaction',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Number' },
    ],
    has => [
        drug_name => { is => 'Text'},
        gene_name => { is => 'Text'},
#TODO: accessors for the associated Genome::GeneName and Genome::DrugName
        drug_gene_interaction_reports => {
            calculate_from => ['drug_name', 'gene_name'],
            calculate => q|
                return Genome::DrugGeneInteractionReport->get(gene_name_report.id => $gene_name, drug_name_report.id => $drug_name);
            |,
        },
    ],
    doc => 'Claim regarding an interaction between a drug name and a gene name',
};

1;
