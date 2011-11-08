package Genome::DruggableGene::DrugNameReportCategoryAssociation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::DrugNameReportCategoryAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'subject.drug_name_report_category_association',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        drug_name_report_id => { is => 'Text' },
        drug_name_report => {
            is => 'Genome::DruggableGene::DrugNameReport',
            id_by => 'drug_name_report_id',
            constraint_name => 'drug_name_report_category_association_drug_name_report_id_fkey',
        },
        category_name => { is => 'Text' },
        category_value => { is => 'Text' },
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    doc => 'Claim regarding categorization of a drug name',
};

1;
