package Genome::SequenceDiffPart;

use strict;
use warnings;

use Genome;
class Genome::SequenceDiffPart {
    type_name => 'sequence diff part',
    table_name => 'SEQUENCE_DIFF_PART',
    id_by => [
        diff_id       => { is => 'INTEGER', is_optional => 1 },
        orig_position => { is => 'INTEGER', is_optional => 1 },
        refseq_path   => { is => 'VARCHAR(256)', is_optional => 1 },
    ],
    has => [
        confidence_value => { is => 'FLOAT', is_optional => 1 },
        orig_length      => { is => 'INTEGER', is_optional => 1 },
        orig_sequence    => { is => 'VARCHAR(36)', is_optional => 1 },
        patched_length   => { is => 'INTEGER', is_optional => 1 },
        patched_position => { is => 'INTEGER', is_optional => 1 },
        patched_sequence => { is => 'VARCHAR(36)', is_optional => 1 },
    ],
    schema_name => 'Diffs',
    data_source => 'Genome::DataSource::Diffs',
};

1;
