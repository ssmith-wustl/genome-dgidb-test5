package Genome::DruggableGene::Citation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::Citation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'dgidb.citation',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        source_db_name => {is => 'Text'},
        source_db_version => {is => 'Text'},
        citation => {is => 'Text'},
    ],
    doc => 'Citation for druggable gene object',
};
