package Genome::SequenceDiffEval;

use strict;
use warnings;

use Genome;
class Genome::SequenceDiffEval {
    type_name => 'sequence diff eval',
    table_name => 'SEQUENCE_DIFF_EVAL',
    id_by => [
        diff_id     => { is => 'INTEGER', is_optional => 1 },
        position    => { is => 'INTEGER', is_optional => 1 },
        refseq_path => { is => 'VARCHAR(256)', is_optional => 1 },
    ],
    has => [
        confidence_value => { is => 'FLOAT', is_optional => 1 },
    ],
    schema_name => 'Diffs',
    data_source => 'Genome::DataSource::Diffs',
};

1;
