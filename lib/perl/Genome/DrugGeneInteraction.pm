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
        drug => {
            is => 'Genome::DrugName',
            id_by => 'drug_name_id',
            constraint_name => 'drug_gene_interaction_drug_name_id_fkey',
        },
        gene_name_id => { is => 'Text'},
        gene => {
            is => 'Genome::GeneName',
            id_by => 'gene_name_id',
            constraint_name => 'drug_gene_interaction_gene_name_id_fkey',
        },
        interaction_type => { is => 'Text'}, 
        description => { is => 'Text' },
        drug_gene_interaction_attributes => {
            calculate_from => ['id'],
            calculate => q|
                my @drug_gene_interaction_attributes = Genome::DrugGeneInteractionAttribute->get(interaction_id => $id);
                return @drug_gene_interaction_attributes;
            |,
        },
    ],
    doc => 'Claim regarding an interaction between a drug name and a gene name',
};

sub __display_name__ {
    my $self = shift;
#TODO: write me
    return "Interaction of " . $self->drug->__display_name__ . " and " . $self->gene->__display_name__;
}

1;
