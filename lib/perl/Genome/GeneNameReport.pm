package Genome::GeneNameReport;

use strict;
use warnings;

use Genome;

class Genome::GeneNameReport {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'gene_name_report',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        name => { is => 'Text'},
        nomenclature => { is => 'Text'},
        source_db_name => { is => 'Text'},
        source_db_version => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
        gene_name_report_associations => {
            is => 'Genome::GeneNameReportAssociation',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        gene_name_report_category_associations => {
            is => 'Genome::GeneNameReportCategoryAssociation',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        drug_gene_interaction_reports => {
            is => 'Genome::DrugGeneInteractionReport',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        drug_name_reports => {
            is => 'Genome::DrugNameReport',
            via => 'drug_gene_interaction_reports',
            to => 'drug_name_report',
            is_many => 1,
        }
    ],
    doc => 'Claim regarding the name of a drug',
};

sub __display_name__ {
    my $self = shift;
    return $self->name . '(' . $self->source_db_name . ' ' . $self->source_db_version . ')';
}

1;
