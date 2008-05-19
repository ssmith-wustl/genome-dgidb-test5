package Genome::Model::Metric;

use strict;
use warnings;

use Genome;

class Genome::Model::Metric {
    type_name => 'genome model metric',
    table_name => 'GENOME_MODEL_METRIC',
    id_by => [
        event                   => { is => 'Genome::Model::Event', id_by => 'event_id', constraint_name => 'GMM_GME_FK' },
        name                    => { is => 'VARCHAR2', len => 100, column_name => 'METRIC_NAME' },
        subject_name            => { is => 'VARCHAR2', len => 100 },
    ],
    has => [
        value                   => { is => 'VARCHAR2', len => 1000, is_optional => 1, column_name => 'METRIC_VALUE' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
