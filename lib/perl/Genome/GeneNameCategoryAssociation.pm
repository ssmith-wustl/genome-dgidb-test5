package Genome::GeneNameCategoryAssociation;

use strict;
use warnings;

use Genome;

class Genome::GeneNameCategoryAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'gene_name_category_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        gene_name_id => { is => 'Text'},
        #TODO: make this work
        # gene_name => {

        # },
        category_name => { is => 'Text' },
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    doc => 'Claim regarding a categorization for a gene name', 
};

1;
