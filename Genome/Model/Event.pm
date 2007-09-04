package Genome::Model::Event;

use strict;
use warnings;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::Model::Event',
    is => ['Command'],
    english_name => 'genome model event',
    table_name => 'genome_model_event',
    id_by => [
        id => { is => 'integer' },
    ],
    has => [
        date_completed  => { is => 'timestamp', is_optional => 1 },
        date_scheduled  => { is => 'timestamp' },
        event_status    => { is => 'varchar2(32)' },
        event_type      => { is => 'varchar2(255)' },
        genome_model    => { is => 'Genome::Model', id_by => 'genome_model_id', constraint_name => 'event_genome_model' },
        genome_model_id => { is => 'integer', implied_by => 'genome_model_id' },
        lsf_job_id      => { is => 'varchar2(64)', is_optional => 1 },
        run             => { is => 'Genome::Run', id_by => 'run_id', constraint_name => 'event_run' },
        run_id          => { is => 'integer', is_optional => 1, implied_by => 'run_id' },
        user_name       => { is => 'varchar2(64)' },
    ],
    data_source => 'Genome::DataSource::Main',
);

1;
