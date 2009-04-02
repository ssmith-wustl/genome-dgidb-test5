package Genome::Model::Build::Link;

use strict;
use warnings;

use Genome;
class Genome::Model::Build::Link {
    type_name => 'genome model build link',
    table_name => 'GENOME_MODEL_BUILD_LINK',
    data_source_id => 'Genome::DataSource::GMSchema',
    id_by => [
        from_build => { is => 'NUMBER', len => 11 },
        to_build   => { is => 'NUMBER', len => 11 },
    ],
    has => [
        role => { is => 'VARCHAR2', len => 56 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema=HASH(0xa333e14)',
};

1;
