package Genome::DruggableGene::GeneNameReportAssociation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::GeneNameReportAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'gene_name_report_association',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        gene_name_report_id => { is => 'Text'},
        gene_name_report => {
            is => 'Genome::DruggableGene::GeneNameReport',
            id_by => 'gene_name_report_id',
            constraint_name => 'gene_name_report_association_gene_name_report_id_fkey',
        },
        alternate_name => {is => 'Text'},
        nomenclature => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    doc => 'Claim regarding an alternate name for a gene name',
};

1;
