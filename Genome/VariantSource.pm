package Genome::VariantSource;

use strict;
use warnings;

use Genome;
class Genome::VariantSource {
    type_name => 'genome variant source',
    table_name => 'GENOME_VARIANT_SOURCE',
    id_by => [
        source_id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        source_name => { is => 'VARCHAR2', len => 255 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
