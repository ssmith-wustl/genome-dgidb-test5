package Genome::DrugNameCategoryAssociation;

use strict;
use warnings;

use Genome;

class Genome::DrugNameCategoryAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_name_category_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        drug_name_id => { is => 'Text' },
        drug_name => {
            is => 'Genome::DrugName',
            id_by => 'drug_name_id',
            constraint_name => 'drug_name_category_association_drug_name_id_fkey',
        },
        category_name => { is => 'Text' },
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    doc => 'Claim regarding categorization of a drug name',
};

1;
