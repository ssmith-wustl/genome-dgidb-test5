package Genome::Model::VariationPosition;

use above 'Genome';

class Genome::Model::VariationPosition {
    id_by => [
        ref_seq_id => { is => 'String', len => 1, doc => 'chromosome' },
        position => { is => 'Integer' },
        model => { is => 'Genome::Model', id_by => 'model_id' },
    ],
    has => [
        reference_base => { is => 'String', },
        consensus_base => { is => 'String', },
        consensus_quality => { is => 'Integer' },
        read_depth => { is => 'Integer'},
        avg_num_hits => { is => 'Float' },
        max_mapping_quality => { is => 'Integer' },
        min_conensus_quality => { is => 'Integer' },
        experimental_metric => { is => 'Genome::Model::ExperimentalMetric', id_by => ['ref_seq_id', 'position','model_id'] },
        metric_snp_quality => { via => 'experimental_metric', to => 'snp_quality' },
    ],
    table_name => 'FILE',  # A dummy table name so the properties get 'column_name' properties
    data_source => 'Genome::DataSource::CsvFileFactory',
};

1;
