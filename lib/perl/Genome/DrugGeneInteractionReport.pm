package Genome::DrugGeneInteractionReport;

use strict;
use warnings;

use Genome;

class Genome::DrugGeneInteractionReport {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_gene_interaction_report',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        drug_name_report_id => { is => 'Text'},
        drug_name_report => {
            is => 'Genome::DrugNameReport',
            id_by => 'drug_name_report_id',
            constraint_name => 'drug_gene_interaction_report_drug_name_report_id_fkey',
        },
        gene_name_report_id => { is => 'Text'},
        gene_name_report => {
            is => 'Genome::GeneNameReport',
            id_by => 'gene_name_report_id',
            constraint_name => 'drug_gene_interaction_report_gene_name_report_id_fkey',
        },
        interaction_type => { is => 'Text'}, 
        description => { is => 'Text', is_optional => 1 },
        drug_gene_interaction_report_attributes => {
            is => 'Genome::DrugGeneInteractionReportAttribute',
            reverse_as => 'drug_gene_interaction_report',
            is_many => 1,
        },
    ],
    doc => 'Claim regarding an interaction between a drug name and a gene name',
};

sub __display_name__ {
    my $self = shift;
    return "Interaction of " . $self->drug_name_report->__display_name__ . " and " . $self->gene_name_report->__display_name__;
}

1;
