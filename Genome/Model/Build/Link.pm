package Genome::Model::Build::Link;

use strict;
use warnings;

use Genome;
class Genome::Model::Build::Link {
    type_name => 'genome model build link',
    table_name => 'GENOME_MODEL_BUILD_LINK',
    data_source_id => 'Genome::DataSource::GMSchema',
    id_by => [
        from_build_id => { is => 'NUMBER', len => 11, implied_by => 'from_build'},
        to_build_id   => { is => 'NUMBER', len => 11, implied_by => 'to_build' },
    ],
    has => [
        role => { is => 'VARCHAR2', len => 56 },
        from_build => { is => 'Genome::Model::Build', 
                        id_by => 'from_build_id',
                        constraint_name => 'GMBL_FB_GMB_FK',
                    },
        to_build => {   is => 'Genome::Model::Build', 
                        id_by => 'to_build_id',
                        constraint_name => 'GMBL_TB_GMB_FK',
                    },
    ],
    schema_name => 'GMSchema',
};

1;
