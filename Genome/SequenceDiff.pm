package Genome::SequenceDiff;

use strict;
use warnings;

use Genome;
class Genome::SequenceDiff {
    type_name => 'sequence diff',
    table_name => 'SEQUENCE_DIFF',
    id_by => [
        diff_id => { is => 'INTEGER', is_optional => 1 },
    ],
    has => [
        description => { is => 'VARCHAR(256)', is_optional => 1 },
        from_path   => { is => 'VARCHAR(256)', is_optional => 1 },
        to_path     => { is => 'VARCHAR(256)', is_optional => 1 },
    ],
    schema_name => 'Diffs',
    data_source => 'Genome::DataSource::Diffs',
};

1;
