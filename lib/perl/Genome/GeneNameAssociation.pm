package Genome::GeneNameAssociation;

use strict;
use warnings;

use Genome;

class Genome::GeneNameAssociation {
    table_name => 'gene_name_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        gene_primary_name => { is => 'Text'},
        gene_alternate_name => {is => 'Text'},
        primary_name_nomenclature => { is => 'Text'},
        alternate_name_nomenclature => { is => 'Text'},
        source_db_name => { is => 'Text'},
        source_db_version => { is => 'Text'},
    ],
    has => [
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
};

1;
