package Genome::Model::ReadSet;

use strict;
use warnings;

use Genome;
class Genome::Model::ReadSet {
    table_name => 'GENOME_MODEL_READ_SET',
    id_by => [
        model               => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMRSET_GM_PK' },
        read_set_id         => { is => 'NUMBER', len => 10 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
