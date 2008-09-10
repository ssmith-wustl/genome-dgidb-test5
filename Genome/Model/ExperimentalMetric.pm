package Genome::Model::ExperimentalMetric;

use above 'Genome';

class Genome::Model::ExperimentalMetric {
    id_by => [
        chromosome => { is => 'String', len => 1 },
        position => { is => 'Integer' },
        model => { is => 'Genome::Model', id_by => 'model_id' },
    ],
    has => [
        reference_base => { is => 'String' },
        variant_base => { is => 'String' },
        snp_quality => { is => 'Integer' },
        total_reads => { is => 'Integer' },
        avg_map_quality=> { is => 'Integer' },
        max_map_quality => { is => 'Integer' },
        n_max_map_quality => { is => 'Integer' },
        avg_sum_of_mismatches => { is => 'Integer' },
        max_sum_of_mismatches=> { is => 'Integer' },
        n_max_sum_of_mismatches => { is => 'Integer' },
        avg_base_quality => { is => 'Integer' },
        max_base_quality => { is => 'Integer' },
        n_max_base_quality=> { is => 'Integer' },
        avg_windowed_quality => { is => 'Integer' },
        max_windowed_quality => { is => 'Integer' },
        n_max_windowed_quality=> { is => 'Integer' },
        plus_strand_unique_by_start_site => { is => 'Integer' },
        minus_strand_unique_by_start_site=> { is => 'Integer' },
        unique_by_sequence_content => { is => 'Integer' },
        plus_strand_unique_by_start_site_pre27=> { is => 'Integer' },
        minus_strand_unique_by_start_site_pre27 => { is => 'Integer' },
        unique_by_sequence_content_pre27 => { is => 'Integer' },
        ref_total_reads=> { is => 'Integer' },
        ref_avg_map_quality => { is => 'Integer' },
        ref_max_map_quality => { is => 'Integer' },
        ref_n_max_map_quality => { is => 'Integer' },
        ref_avg_sum_of_mismatches=> { is => 'Integer' },
        ref_max_sum_of_mismatches => { is => 'Integer' },
        ref_n_max_sum_of_mismatches => { is => 'Integer' },
        ref_avg_base_quality => { is => 'Integer' },
        ref_max_base_quality=> { is => 'Integer' },
        ref_n_max_base_quality => { is => 'Integer' },
        ref_avg_windowed_quality => { is => 'Integer' },
        ref_max_windowed_quality => { is => 'Integer' },
        ref_n_max_windowed_quality=> { is => 'Integer' },
        ref_plus_strand_unique_by_start_site => { is => 'Integer' },
        ref_minus_strand_unique_by_start_site=> { is => 'Integer' },
        ref_unique_by_sequence_content => { is => 'Integer' },
        ref_plis_strand_unique_by_start_site_pre27=> { is => 'Integer' },
        ref_minus_strand_unique_by_start_site_pre27 => { is => 'Integer' },
        ref_unique_by_sequence_content_pre27=> { is => 'Integer' },
    ],
    table_name => 'FILE1',  # A dummy table name so the properties get 'column_name' properties
    data_source => 'Genome::DataSource::CsvFileFactory',
};

1;
