package Genome::SequenceDiffEval;

use strict;
use warnings;

use Genome;
class Genome::SequenceDiffEval {
    type_name => 'sequence diff eval',
    table_name => 'SEQUENCE_DIFF_EVAL',
    id_by => [
        diff_id       => { is => 'NUMBER', len => 10 },
        position      => { is => 'NUMBER', len => 10 },
        refseq_path   => { is => 'VARCHAR2', len => 256 },
        sequence_diff => { is => 'Genome::SequenceDiff', id_by => 'diff_id', constraint_name => 'SDE_FK' },
    ],
    has => [
        confidence_value => { is => 'NUMBER', len => 10, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
