package Genome::UrmetaGenomeModelEventIdSeq;

use strict;
use warnings;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::UrmetaGenomeModelEventIdSeq',
    english_name => 'urmeta genome model event id seq',
    table_name => 'URMETA_GENOME_MODEL_EVENT_ID_SEQ',
    er_role => 'validation item',
    id_by => [
        next_value => { is => 'INT', len => 11 },
    ],
    unique_constraints => [
        { properties => [qw/next_value/], sql => 'PRIMARY' },
    ],
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);

1;
