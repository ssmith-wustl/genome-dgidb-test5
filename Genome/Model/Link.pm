package Genome::Model::Link;

use strict;
use warnings;

use Genome;
class Genome::Model::Link {
    type_name => 'genome model link',
    table_name => 'GENOME_MODEL_LINK',
    data_source_id => 'Genome::DataSource::GMSchema',
    id_by => [
        to_model   => { is => 'NUMBER', len => 11 },
        from_model => { is => 'NUMBER', len => 11 },
    ],
    has => [
        role => { is => 'VARCHAR2', len => 56 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema=HASH(0xa333e14)',
};

1;
