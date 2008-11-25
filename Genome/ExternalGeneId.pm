package Genome::ExternalGeneId;

use strict;
use warnings;

use Genome;

class Genome::ExternalGeneId {
    type_name => 'genome external gene id',
    table_name => 'EXTERNAL_GENE_ID',
    id_by => [
        egi_id => { is => 'NUMBER' },
    ],
    has => [
        gene_id => { is => 'NUMBER' },
        id_type => { is => 'String' },
        id_value => { is => 'String' },
        
        gene => { is => 'Genome::Gene', id_by => 'gene_id' },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::ExternalGeneIds',
};

1;

