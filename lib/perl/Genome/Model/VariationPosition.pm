package Genome::Model::VariationPosition;

use above 'Genome';

class Genome::Model::VariationPosition {
    id_by => [
        ref_seq_name => { is => 'String', len => 1, doc => 'chromosome' },
        position     => { is => 'Integer' },
        model        => { is => 'Genome::Model', id_by => 'model_id' },
    ],
    has => [
        model_name   => { via => 'model', to => 'name' },
        model_refseq => { is => 'Genome::Model::RefSeq', id_by => ['model_id','ref_seq_name'] },
        ref_seq_id   => { via => 'model_refseq', to => 'ref_seq_id' },

        reference_base => { is => 'String', },
        consensus_base => { is => 'String', },
        consensus_quality => { is => 'Integer' },
        read_depth => { is => 'Integer'},
        avg_num_hits => { is => 'Float' },
        max_mapping_quality => { is => 'Integer' },
        min_conensus_quality => { is => 'Integer' },
        experimental_metric => { is => 'Genome::Model::ExperimentalMetric', id_by => ['ref_seq_name', 'position','model_id'] },
        metric_snp_quality => { via => 'experimental_metric', to => 'snp_quality' },
    ],
#    table_name => 'FILE',  # A dummy table name so the properties get 'column_name' properties
    data_source => 'Genome::DataSource::VariationPosition',
};

1;
