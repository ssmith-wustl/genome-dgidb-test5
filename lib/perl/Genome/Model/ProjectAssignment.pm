package Genome::Model::ProjectAssignment;

use strict;
use warnings;

use Genome;
class Genome::Model::ProjectAssignment {
    type_name => 'genome model research project',
    table_name => 'GENOME_MODEL_RESEARCH_PROJECT',
    id_by => [
        model   => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMRP_GM_FK' },
        project => { is => 'Genome::Project', id_by => 'rp_id' },
    ],
    has_optional => [
        description => { is => 'VARCHAR2', len => 1000 },
        ticket_id   => { is => 'VARCHAR2', len => 64 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

