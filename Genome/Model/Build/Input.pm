package Genome::Model::Build::Input;

use strict;
use warnings;

use Genome;
class Genome::Model::BuildInput {
    type_name => 'genome model build input',
    table_name => 'GENOME_MODEL_BUILD_INPUT',
    subclassify_by => 'input_class_name',
    id_by => [
        build_id         => { is => 'NUMBER', len => 11 },
        value_class_name => { is => 'VARCHAR2', len => 255 },
        value_id         => { is => 'VARCHAR2', len => 1000 },
        name             => { is => 'VARCHAR2', len => 255, },
    ],
    has => [
    model => {
        is => 'Genome::Model',
        via => 'build',
    },
    build => { 
        is => 'Genome::Model::Build', 
        id_by => 'build_id',
        constraint_name => 'GMBI_GMB_FK',
    },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

#$HeadURL$
#$Id$
