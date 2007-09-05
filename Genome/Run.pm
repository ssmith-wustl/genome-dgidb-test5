package Genome::RunChunk;

use strict;
use warnings;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::RunChunk',
    english_name => 'run chunk',
    table_name => 'run',
    id_by => [
        id => { is => 'integer' },
    ],
    has => [
        full_path           => { is => 'varchar2(1000)' },
        limit_regions       => { is => 'varchar2(32)', is_optional => 1 },
        sample_name         => { is => 'varchar2(255)' },
        sequencing_platform => { is => 'varchar2(255)' },
    ],
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);

1;
