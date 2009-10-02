package Genome::Model::Input;

use strict;
use warnings;

use Genome;
class Genome::Model::Input {
    type_name => 'genome model input',
    table_name => 'GENOME_MODEL_INPUT',
    id_by => [
        input_class_name => { is => 'VARCHAR2', len => 255 },
        input_id         => { is => 'VARCHAR2', len => 1000 },
        model_id         => { is => 'NUMBER', len => 11 },
    ],
    has => [
        genome_model_model => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMI_GM_FK' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
