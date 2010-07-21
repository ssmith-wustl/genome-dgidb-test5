package Genome::DataSource::ExperimentalMetric;

use Genome;

class Genome::DataSource::ExperimentalMetric {
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub constant_values { ['model_id'] };
sub required_for_get { [ qw( model_id ref_seq_id )] }
sub delimiter { ',\s*' }
sub column_order { [ qw(chromosome position reference_base variant_base snp_quality
                      total_reads avg_map_quality max_map_quality n_max_map_quality avg_sum_of_mismatches
                      max_sum_of_mismatches n_max_sum_of_mismatches avg_base_quality max_base_quality
                      n_max_base_quality avg_windowed_quality max_windowed_quality n_max_windowed_quality
                      plus_strand_unique_by_start_site minus_strand_unique_by_start_site
                      unique_by_sequence_content plus_strand_unique_by_start_site_pre27
                      minus_strand_unique_by_start_site_pre27 unique_by_sequence_content_pre27 ref_total_reads
                      ref_avg_map_quality ref_max_map_quality ref_n_max_map_quality ref_avg_sum_of_mismatches
                      ref_max_sum_of_mismatches ref_n_max_sum_of_mismatches ref_avg_base_quality ref_max_base_quality
                      ref_n_max_base_quality ref_avg_windowed_quality ref_max_windowed_quality ref_n_max_windowed_quality
                      ref_plus_strand_unique_by_start_site ref_minus_strand_unique_by_start_site
                      ref_unique_by_sequence_content ref_plis_strand_unique_by_start_site_pre27
                      ref_minus_strand_unique_by_start_site_pre27 ref_unique_by_sequence_content_pre27
                      total_depth cns2_snp_depth cns2_avg_num_reads cns2_max_map_quality cns2_quality_difference_btw_strong_and_weak_alleles)] }
sub sort_order { [qw(chromosome position)] }
sub skip_first_line { 1; }

sub file_resolver {
    my($model_id, $ref_seq_id) = @_;

    my $model = Genome::Model->get(id => $model_id);
    return unless $model;

    my $refseq = Genome::Model::RefSeq->get(model_id => $model_id, ref_seq_id => $ref_seq_id);
    return unless $refseq;

    my($metric_file) = $model->_variation_metrics_files($refseq->ref_seq_name);
    return $metric_file;
}


1;
