package Genome::DrugName;

use strict;
use warnings;

use Genome;

class Genome::DrugName {
    table_name => 'drug_name',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        name => { is => 'varchar'},
        nomenclature => { is => 'varchar'},
        source_db_name => { is => 'varchar'},
        source_db_version => { is => 'varchar'},
    ],
    has => [
        description => {
            is => 'Text',
            is_optional => 1,
        },
        drug_name_associations => {
            calculate_from => ['name', 'nomenclature', 'source_db_name', 'source_db_version'],
            calculate => q|
                my @drug_name_associations = Genome::DruggableGene::DrugNameAssociation->get(drug_primary_name => $name, nomenclature => $nomenclature, source_db_name => $source_db_name, source_db_version => $source_db_version);
                return @drug_name_associations;
            |,
        },
        drug_name_category_associations => {
            calculate_from => ['name', 'nomenclature', 'source_db_name', 'source_db_version'],
            calculate => q|
                my @drug_name_category_associations = Genome::DruggableGene::DrugNameCategoryAssociation->get(drug_name => $name, nomenclature => $nomenclature, source_db_name => $source_db_name, source_db_version => $source_db_version);
                return @drug_name_category_associations;
            |,
        },
    ],
};

1;
