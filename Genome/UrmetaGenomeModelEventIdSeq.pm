package Genome::UrmetaGenomeModelEventIdSeq;

use strict;
use warnings;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::UrmetaGenomeModelEventIdSeq',
    english_name => 'urmeta genome model event id seq',
    table_name => 'URMETA_genome_model_event_id_seq',
    er_role => 'validation item',
    id_by => [
        next_value => { is => 'integer', is_optional => 1 },
    ],
    data_source => 'Genome::DataSource::Main',
);

1;
