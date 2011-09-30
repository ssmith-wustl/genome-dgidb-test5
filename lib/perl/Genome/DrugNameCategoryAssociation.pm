package Genome::DrugNameCategoryAssociation;

use strict;
use warnings;

use Genome;

class Genome::DrugNameCategoryAssociation {
    table_name => 'drug_name_category_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        drug_name => { is => 'Text' },
        category_name => { is => 'Text' },
        nomenclature => { is => 'Text' },
        source_db_name => { is => 'Text' },
        source_db_version => { is => 'Text' },
    ],
    has => [
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
};

1;
