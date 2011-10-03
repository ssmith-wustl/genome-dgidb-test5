package Genome::GeneName;

use strict;
use warnings;

use Genome;

class Genome::GeneName {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'gene_name',
    schema_name => 'public',
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
        gene_name_associations => {
            calculate_from => ['name', 'nomenclature', 'source_db_name', 'source_db_version'],
            calculate => q|
                my @gene_name_associations = Genome::GeneNameAssociation->get(gene_primary_name => $name, nomenclature => $nomenclature, source_db_name => $source_db_name, source_db_version => $source_db_version);
                return @gene_name_associations;
            |,
        },
        gene_name_category_associations => {
            calculate_from => ['name', 'nomenclature', 'source_db_name', 'source_db_version'],
            calculate => q|
                my @gene_name_category_associations = Genome::GeneNameCategoryAssociation->get(gene_name => $name, nomenclature => $nomenclature, source_db_name => $source_db_name, source_db_version => $source_db_version);
                return @gene_name_category_associations;
            |,
        },
    ],
    doc => 'Claim regarding the name of a drug',
};

1;
