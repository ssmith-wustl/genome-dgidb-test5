package Genome::ModelSet;

use strict;
use warnings;

use Genome;
class Genome::ModelSet {
    type_name => 'model set',
    table_name => 'MODEL_SET',
    id_by => [
        model_set_id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        genome_model_model => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'MS_GM_FK' },
        model_id           => { is => 'NUMBER', len => 10 },
        name               => { is => 'VARCHAR2', len => 50 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
