package Genome::Model::RefSeq::Metric;

use strict;
use warnings;

use Genome;
class Genome::Model::RefSeq::Metric {
    table_name => 'GENOME_MODEL_REF_SEQ_METRIC',
    id_by => [
        ref_seq     => { is => 'Genome::Model::RefSeq', id_by => ['model_id', 'ref_seq_id'], constraint_name => 'GMRSM_GMRS_PK' },
        name        => { is => 'VARCHAR2', len => 200 },
    ],
    has => [
        value       => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
