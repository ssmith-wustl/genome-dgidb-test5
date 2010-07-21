# Review: gsanders not sure what this is used for, check...

package Genome::DataSource::VariationPosition;

use Genome;

class Genome::DataSource::VariationPosition {
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub constant_values { ['model_id'] };
sub required_for_get { [qw( model_id ref_seq_id )] }
sub delimiter { '\s+' }
sub column_order { [ qw(ref_seq_name position reference_base consensus_base consensus_quality
                      read_depth avg_num_hits max_mapping_quality min_conensus_quality)] }
sub sort_order { [qw(ref_seq_name position )] }
sub skip_first_line { 0; }

sub file_resolver {
    my($model_id, $ref_seq_id) = @_;

    my $model = Genome::Model->get(id => $model_id);
    return unless $model;

    # We're really only interested in the ref_seq_name, but we'll use
    # the trick of saying we require ref_seq_id so  it'll infer all the
    # refseqs attached to that model if the user didn't specify a model
    my $refseq = Genome::Model::RefSeq->get(model_id => $model_id, ref_seq_id => $ref_seq_id);
    return unless $refseq;

    my($snp_file) = $model->_variant_list_files($refseq->ref_seq_name);

    return $snp_file;
}

1;
