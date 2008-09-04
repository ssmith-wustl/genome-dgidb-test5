package Genome::Model::VariationPosition;

use Genome;

class Genome::Model::VariationPosition {
    id_by => [
        ref_seq_id => { is => 'String', len => 1, doc => 'chromosome' },
        position => { is => 'Integer' },
    ],
    has => [
        #model_id => { is => 'Integer' },
        model => { is => 'Genome::Model', id_by => 'model_id' },
        reference_base => { is => 'String', },
        consensus_base => { is => 'String', },
        consensus_quality => { is => 'Integer' },
        read_depth => { is => 'Integer'},
        avg_num_hits => { is => 'Float' },
        max_mapping_quality => { is => 'Integer' },
        min_conensus_quality => { is => 'Integer' },
    ],
    table_name => 'FILE',  # A dummy table name so the properties get 'column_name' properties
    data_source => 'Genome::DataSource::VariationPositions',
};

1;
