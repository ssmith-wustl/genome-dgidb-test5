package Genome::Model::ResearchProject;

use strict;
use warnings;

use Genome;
class Genome::Model::ResearchProject {
    table_name => 'GENOME_MODEL_RESEARCH_PROJECT',
    has => [
        model_id  => { is => 'NUMBER', len => 10 },
        description   => { is => 'VARCHAR2', len => 1000, is_optional => 1, column_name => 'RP_DESC' },
        rp_id     => { is => 'NUMBER', len => 10 },
        ticket_id => { is => 'VARCHAR2', len => 64, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

