package Genome::SequenceDiffPart;

use strict;
use warnings;

use Genome;
class Genome::SequenceDiffPart {
    type_name => 'sequence diff part',
    table_name => 'SEQUENCE_DIFF_PART',
    id_by => [
        delete_position => { is => 'NUMBER', len => 10 },
        diff_id         => { is => 'NUMBER', len => 10 },
        refseq_path     => { is => 'VARCHAR2', len => 256 },
        sequence_diff   => { is => 'Genome::SequenceDiff', id_by => 'diff_id', constraint_name => 'SDP_FK' },
    ],
    has => [
        confidence_value => { is => 'NUMBER', len => 10, is_optional => 1 },
        delete_length    => { is => 'NUMBER', len => 10, is_optional => 1 },
        delete_sequence  => { is => 'VARCHAR2', len => 4000, is_optional => 1 },
        insert_length    => { is => 'NUMBER', len => 10, is_optional => 1 },
        insert_position  => { is => 'NUMBER', len => 10, is_optional => 1 },
        insert_sequence  => { is => 'VARCHAR2', len => 4000, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
