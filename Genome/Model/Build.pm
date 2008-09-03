package Genome::Model::Build;

use strict;
use warnings;

use Genome;
class Genome::Model::Build {
    table_name => 'GENOME_MODEL_BUILD',
    is => 'Genome::Model::Event',
    id_by => [
        build_id           => { is => 'NUMBER', len => 10 },
    ],
    has => [
        model              => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMB_GMM_FK' },
        data_directory     => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

