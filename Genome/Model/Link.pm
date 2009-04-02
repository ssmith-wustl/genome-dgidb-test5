package Genome::Model::Link;

use strict;
use warnings;

use Genome;
class Genome::Model::Link {
    type_name => 'genome model link',
    table_name => 'GENOME_MODEL_LINK',
    data_source_id => 'Genome::DataSource::GMSchema',
    id_by => [
        from_model_id => { is => 'NUMBER', len => 11, implied_by => 'from_model' },
        to_model_id   => { is => 'NUMBER', len => 11, implied_by => 'to_model' },
    ],
    has => [
        role => { is => 'VARCHAR2', len => 56 },
        from_model => { is => 'Genome::Model', 
                        id_by => 'from_model_id',
                        constraint_name => 'GML_FB_GM_FK',
                    },
        to_model => {   is => 'Genome::Model', 
                        id_by => 'to_model_id',
                        constraint_name => 'GML_TB_GM_FK',
                    },
    ],
    schema_name => 'GMSchema',
};

1;
