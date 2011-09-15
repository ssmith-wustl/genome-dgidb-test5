package Genome::DruggableGene::GeneNameCategoryAssociation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::GeneNameCategoryAssociation {
    table_name => 'gene_name_category_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        gene_name => { is => 'varchar' },
        category_name => { is => 'varchar' },
        nomenclature => { is => 'varchar' },
        source_db_name => { is => 'varchar' },
        source_db_version => { is => 'varchar' },
    ],
    has => [
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
};

1;
