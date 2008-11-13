package Genome::Model::ReadSetMetric;

use strict;
use warnings;

use Genome;
class Genome::Model::ReadSetMetric {
    type_name => 'genome model read set metric',
    table_name => 'GENOME_MODEL_READ_SET_METRIC',
    id_by => [
        metric_name  => { is => 'VARCHAR2', len => 255 },
        build_id     => { is => 'NUMBER', len => 10 },
        read_set_id  => { is => 'NUMBER', len => 10 },
        metric_value => { is => 'VARCHAR2', len => 1000 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
