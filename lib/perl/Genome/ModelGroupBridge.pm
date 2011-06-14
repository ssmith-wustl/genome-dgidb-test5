package Genome::ModelGroupBridge;

use strict;
use warnings;

use Genome;

class Genome::ModelGroupBridge {
    type_name  => 'genome model group bridge',
    table_name => 'GENOME_MODEL_GROUP',
    er_role    => 'bridge',
    id_by      => [
        model_group_id => { is => 'UR::Value::Number', len => 11 },
        model_id       => { is => 'UR::Value::Number', len => 11 },
    ],
    has => [
        model => {
            is              => 'Genome::Model',
            id_by           => 'model_id',
            constraint_name => 'GMG_GM_FK'
        },
        model_group => {
            is              => 'Genome::ModelGroup',
            id_by           => 'model_group_id',
            constraint_name => 'GMG_MG_FK'
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
