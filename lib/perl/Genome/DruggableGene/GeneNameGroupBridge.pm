package Genome::DruggableGene::GeneNameGroupBridge;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::GeneNameGroupBridge {
    is => 'UR::Object',
    table_name => 'dgidb.gene_name_group_bridge',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',

    id_by => [
        gene_name_group_id => { is => 'Text'},
        gene_name_report_id => { is => 'Text'},
    ],
    has => [
        gene_name_group => {
            is => 'Genome::DruggableGene::GeneNameGroup',
            id_by => 'gene_name_group_id',
        },
        gene_name_report => {
            is => 'Genome::DruggableGene::GeneNameReport',
            id_by => 'gene_name_report_id',
        },
    ],
    doc => 'Associate a gene that is likely synonymous with other genes in this group',
};

1;
