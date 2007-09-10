package Genome::UrmetaRunIdSeq;

use strict;
use warnings;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::UrmetaRunIdSeq',
    english_name => 'urmeta run id seq',
    table_name => 'URMETA_run_id_seq',
    er_role => 'validation item',
    id_by => [
        next_value => { is => 'integer', is_optional => 1 },
    ],
    data_source => 'Genome::DataSource::Main',
);

1;
