package Genome::DruggableGene::DrugNameReportAssociation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::DrugNameReportAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_name_report_association',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        drug_name_report_id => { is => 'Text'},
        drug_name_report => {
            is => 'Genome::DruggableGene::DrugNameReport',
            id_by => 'drug_name_report_id',
            constraint_name => 'drug_name_report_association_drug_name_report_id_fkey',
        },
        alternate_name => {is => 'Text'},
        nomenclature => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    doc => 'Claim regarding an alternate name for a drug name',
};

1;
