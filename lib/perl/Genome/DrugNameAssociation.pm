package Genome::DruggableGene::DrugNameAssociation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::DrugNameAssociation {
    table_name => 'drug_name_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        drug_primary_name => { is => 'varchar'},
        drug_alternate_name => {is => 'varchar'},
        primary_name_nomenclature => { is => 'varchar'},
        alternate_name_nomenclature => { is => 'varchar'},
        source_db_name => { is => 'varchar'},
        source_db_version => { is => 'varchar'},
    ],
    has => [
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
};

1;
