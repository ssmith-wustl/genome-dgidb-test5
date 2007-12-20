package Genome::UrmetaRunIdSeq;

use strict;
use warnings;

use Genome;
UR::Object::Type->define(
    class_name => 'Genome::UrmetaRunIdSeq',
    english_name => 'urmeta run id seq',
    table_name => 'URMETA_RUN_ID_SEQ',
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
