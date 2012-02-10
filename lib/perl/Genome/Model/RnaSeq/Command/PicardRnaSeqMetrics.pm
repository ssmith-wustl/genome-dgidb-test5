package Genome::Model::RnaSeq::Command::PicardRnaSeqMetrics;

use strict;
use warnings;

use Genome;

my $DEFAULT_LSF_RESOURCE = "-R 'select[mem>=8000] rusage[mem=8000]' -M 8000000";

class Genome::Model::RnaSeq::Command::PicardRnaSeqMetrics {
    is => ['Command::V2'],
    has_input_output => [
        build_id => {},
    ],
    has => [
        picard_version => {
            is_optional => 1,
            is_input => 1,
        },
        build => { is => 'Genome::Model::Build::RnaSeq', id_by => 'build_id', },
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
    doc => 'generate metrics on pipeline results' 
};

sub sub_command_category { 'pipeline' }

sub sub_command_sort_position { 5 }

sub execute {
    my $self = shift;

    unless ($self->picard_version) {
        $self->picard_version($self->build->model->picard_version);
    }
    
    my $alignment_result = $self->build->alignment_result;
    my $bam_file = $alignment_result->bam_file;

    my $reference_build = $self->build->model->reference_sequence_build;
    my $reference_path = $reference_build->full_consensus_path('fa');
    my $seqdict_file = $reference_build->get_sequence_dictionary('sam',$reference_build->species_name,$self->picard_version);
    
    my $annotation_reference_transcripts = $self->build->model->annotation_reference_transcripts;
    my $annotation_build;
    if ($annotation_reference_transcripts) {
        my ($annotation_name,$annotation_version) = split(/\//, $annotation_reference_transcripts);
        my $annotation_model = Genome::Model->get(name => $annotation_name);
        unless ($annotation_model){
            $self->error_message('Failed to get annotation model for annotation_reference_transcripts: ' . $annotation_reference_transcripts);
            return;
        }

        unless (defined $annotation_version) {
            $self->error_message('Failed to get annotation version from annotation_reference_transcripts: '. $annotation_reference_transcripts);
            return;
        }

        $annotation_build = $annotation_model->build_by_version($annotation_version);
        unless ($annotation_build){
            $self->error_message('Failed to get annotation build from annotation_reference_transcripts: '. $annotation_reference_transcripts);
            return;
        }
    } else {
        $self->status_message('Skipping PicardRnaSeqMetrics since annotation_reference_transcripts is not defined');
        return 1;
    }
    my $metrics_directory = $self->build->metrics_directory;
    unless (-d $metrics_directory) {
        Genome::Sys->create_directory($metrics_directory);
    }
    
    my $rRNA_MT_gtf_file = $annotation_build->rRNA_MT_file('gtf',$reference_build->id,0);
    unless (Genome::Model::Tools::Gtf::ToIntervals->execute(
        gtf_file => $rRNA_MT_gtf_file,
        seqdict_file => $seqdict_file,
        interval_file => $self->build->picard_rna_seq_ribo_intervals,
    )) {
        $self->error_message('Failed to convert the rRNA_MT GTF file to intervals: '. $rRNA_MT_gtf_file);
        return;
    }
    
    my $mRNA_gtf_file = $annotation_build->annotation_file('gtf',$reference_build->id,0);
    unless (Genome::Model::Tools::Gtf::ToRefFlat->execute(
        input_gtf_file => $mRNA_gtf_file,
        output_file => $self->build->picard_rna_seq_mRNA_ref_flat,
    )) {
        $self->error_message('Failed to convert the all_sequences GTF file to intervals: '. $mRNA_gtf_file);
        return;
    }

    my $tmp_bam_file = Genome::Sys->create_temp_file_path();
    unless (Genome::Model::Tools::Picard::ReorderSam->execute(
        input_file => $bam_file,
        output_file => $tmp_bam_file,
        reference_file => $reference_path,
        use_version => $self->picard_version,
    )) {
        $self->error_message('Failed to reorder BAM file: '. $bam_file);
        return;
    }

    unless (Genome::Model::Tools::Picard::CollectRnaSeqMetrics->execute(
        input_file => $tmp_bam_file,
        output_file => $self->build->picard_rna_seq_metrics,
        refseq_file => $reference_path,
        ribosomal_intervals_file => $self->build->picard_rna_seq_ribo_intervals,
        ref_flat_file => $self->build->picard_rna_seq_mRNA_ref_flat,
        use_version => $self->picard_version,
        chart_output => $self->build->picard_rna_seq_chart,
    )) {
        $self->error_message('Failed to run Picard CollectRnaSeqMetrics for build: '. $self->build_id);
        return;
    }
    unless (Genome::Model::Tools::Picard::PlotRnaSeqMetrics->execute(
        input_file => $self->build->picard_rna_seq_metrics,
        output_file => $self->build->picard_rna_seq_pie_chart,
        label => $self->build->model->subject_name .' '. $self->build_id,
    )) {
        $self->error_message('Failed to run PlotRnaSeqMetrics for build: '. $self->build_id);
        return;
    }
    unless ($self->_save_metrics) {
        $self->error_message("Failed saving metrics: " . $self->error_message);
        return;
    }
    return 1;
}


sub _save_metrics {
    my $self = shift;

    my $rna_seq_metrics = $self->build->picard_rna_seq_metrics;
    my $metrics_hash_ref = Genome::Model::Tools::Picard::CollectRnaSeqMetrics->parse_file_into_metrics_hashref($rna_seq_metrics);
    for my $metric_name (keys %{$metrics_hash_ref}) {
        my $metric = Genome::Model::Metric->create(
            build => $self->build,
            name => $metric_name,
            value => $metrics_hash_ref->{$metric_name},
        );
        unless($metric) {
            $self->error_message('Failed to create metric for: '. $metric_name);
            return;
        }
    }
    return 1;
}


1;
