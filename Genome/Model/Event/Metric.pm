package Genome::Model::Event::Metric;

use strict;
use warnings;

use Genome;
class Genome::Model::Event::Metric {
    type_name => 'genome model event metric',
    table_name => 'GENOME_MODEL_EVENT_METRIC',
    id_by => [
        event   => { is => 'Genome::Model::Event', id_by => 'event_id', constraint_name => 'GMEM_GME_FK' },
        name    => { is => 'VARCHAR2', len => 100, column_name => 'METRIC_NAME' },
    ],
    has => [
        value   => { is => 'VARCHAR2', len => 1000, is_optional => 1, column_name => 'METRIC_VALUE' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
