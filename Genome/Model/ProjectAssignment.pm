package Genome::Model::ProjectAssignment;

use strict;
use warnings;

use Genome;
class Genome::Model::ProjectAssignment {
    type_name => 'genome model research project',
    table_name => 'GENOME_MODEL_RESEARCH_PROJECT',
    id_by => [
        model           => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMRP_GM_FK' },
        rp_id           => { is => 'NUMBER', len => 10 },
    ],
    has => [
        description     => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        ticket_id       => { is => 'VARCHAR2', len => 64, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

