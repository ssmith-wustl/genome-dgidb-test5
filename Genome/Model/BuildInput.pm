package Genome::Model::BuildInput;

use strict;
use warnings;

use Genome;
class Genome::Model::BuildInput {
    type_name => 'genome model build input',
    table_name => 'GENOME_MODEL_BUILD_INPUT',
    id_by => [
        build_id         => { is => 'NUMBER', len => 11 },
        input_class_name => { is => 'VARCHAR2', len => 255 },
        input_id         => { is => 'VARCHAR2', len => 1000 },
    ],
    has => [
        genome_model_build => { is => 'Genome::Model::Build', id_by => 'build_id', constraint_name => 'GMBI_GMB_FK' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
