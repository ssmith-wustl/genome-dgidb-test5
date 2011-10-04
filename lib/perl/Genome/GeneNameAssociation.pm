package Genome::GeneNameAssociation;

use strict;
use warnings;

use Genome;

class Genome::GeneNameAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'gene_name_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        gene_name_id => { is => 'Text'},
        gene_name => {
            is => 'Genome::GeneName',
            id_by => 'gene_name_id',
            constraint_name => 'gene_name_association_gene_name_id_fkey',
        },
        alternate_name => {is => 'Text'},
        nomenclature => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    doc => 'Claim regarding an alternate name for a gene name',
};

1;
