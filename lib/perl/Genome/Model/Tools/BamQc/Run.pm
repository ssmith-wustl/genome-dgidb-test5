package Genome::Model::Tools::BamQc::Run;

use strict;
use warnings;

use Genome;

my $DEFAULT_PICARD_VERSION = Genome::Model::Tools::Picard->default_picard_version;
my $DEFAULT_SAMSTAT_VERSION = Genome::Model::Tools::SamStat::Base->default_samstat_version;
my $DEFAULT_FASTQC_VERSION = '0.10.0'; #Genome::Model::Tools::Fastqc->default_fastqc_version;

class Genome::Model::Tools::BamQc::Run {
    is => ['Genome::Model::Tools::BamQc::Base'],
    has_input => [
        bam_file => {
            doc => 'The input BAM file.'
        },
        output_directory => { },
        reference_sequence => {
            is_optional => 1,
            # GRCh37-lite-build37
            default_value => '/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fasta',
        },
        # TODO: Add option for aligner, bwasw would require some additional tools
    ],
    has_optional_input => [
        roi_file_path => {
        },
        roi_file_format => {
        },
        picard_version => {
            default_value => $DEFAULT_PICARD_VERSION,
        },
        samstat_version => {
            default_value => $DEFAULT_SAMSTAT_VERSION,
        },
        fastqc_version => {
            default_value => $DEFAULT_FASTQC_VERSION,
        },
        picard_maximum_memory => {
            default_value => '30',
        },
        picard_maximum_permgen_memory => {
            default_value => '256',
        },
        picard_max_records_in_ram => {
            default_value => '5000000',
        },
        error_rate_pileup => {
            is => 'Boolean',
            default_value => 1,
        },
    ],
};

# TODO: I thought about running RefCov on the entire genome, but it may be computationally intensive(~several hours)
#sub create {
    #my $class = shift;
    #my %params = @_;
    #my $self = $class->SUPER::create(%params);
    #unless ($self) { return; }
    #unless ($self->roi_file_path) {
    #    $self->roi_file_path($self->bam_file);
    #    $self->roi_file_format('bam');
    #}
    #return $self;
#}

sub execute {
    my $self = shift;
    my %data;
    # TODO: Make this a workflow to run distributed across LSF

    my ($bam_basename,$bam_dirname,$bam_suffix) = File::Basename::fileparse($self->bam_file,qw/\.bam/);
    my $file_basename = $self->output_directory .'/'. $bam_basename;

    my $bam_path = $file_basename .'.bam';
    unless (-e $bam_path) {
        unless (symlink($self->bam_file,$bam_path)) {
            die('Failed to create symlink '. $bam_path .' -> '. $self->bam_file);
        }
    }

    # SAMTOOLS
    my $bai_path = $file_basename .'.bam.bai';
    unless (-e $bai_path) {
        my $bai_file = $self->bam_file .'.bai';
        if ($bai_file) {
            unless (symlink($bai_file,$bai_path)) {
                die('Failed to create symlink '. $bai_path .' -> '. $bai_file);
            }
        } else {
            # TODO: check if BAM is sorted (I think only Picard adds the sortorder to the header)
            # TODO: run samtools index or Picard index
            die('Add samtools index!')
        }
    }
    my $flagstat_path = $file_basename .'.bam.flagstat';
    unless (-e $flagstat_path) {
        my $flagstat_file = $self->bam_file .'.flagstat';
        if ($flagstat_file) {
            unless (symlink($flagstat_file,$flagstat_path)) {
                die('Failed to create symlinke '. $flagstat_path .' -> '. $flagstat_file);
            }
        } else {
            # TODO: run samtools flagstat
            die('Add samtools flagstat!');
        }
    }

    # PICARD MARKDUPLICATES
    my @mrkdup_files = glob($bam_dirname .'/*.metrics');
    unless (@mrkdup_files) {
        # TODO: run MarkDuplicates
    }

    # PICARD METRICS
    my $picard_metrics_basename = $file_basename .'-PicardMetrics';
    my %picard_metrics_params = (
        use_version => $self->picard_version,
        reference_sequence => $self->reference_sequence,
        input_file => $bam_path,
        output_basename => $picard_metrics_basename,
        maximum_permgen_memory => $self->picard_maximum_permgen_memory,
        maximum_memory => $self->picard_maximum_memory,
    );
    unless (Genome::Model::Tools::Picard::CollectMultipleMetrics->execute(%picard_metrics_params)) {
        die('Failed to run Picard CollectMultipleMetrics with parameters: '. Data::Dumper::Dumper(%picard_metrics_params));
    }

    # PICARD GC
    my $picard_gc_metrics_file = $file_basename .'-PicardGC_metrics.txt';
    my $picard_gc_chart_file = $file_basename .'-PicardGC_chart.pdf';
    my $picard_gc_summary_file = $file_basename .'-PicardGC_summary.txt';
    my %picard_gc_params = (
        use_version => $self->picard_version,
        clean_bam => 'none',
        max_records_in_ram => $self->picard_max_records_in_ram,
        maximum_permgen_memory => $self->picard_maximum_permgen_memory,
        maximum_memory => $self->picard_maximum_memory,
        refseq_file => $self->reference_sequence,
        input_file => $bam_path,
        output_file => $picard_gc_metrics_file,
        chart_output => $picard_gc_chart_file,
        summary_output => $picard_gc_summary_file,
    );
    unless (Genome::Model::Tools::Picard::CollectGcBiasMetrics->execute(%picard_gc_params)) {
        die('Failed to run Picard CollectGcBiasMetrics with parameters: '. Data::Dumper::Dumper(%picard_gc_params));
    }

    # REFCOV
    my $refcov_stats_file = $file_basename .'-RefCov_STATS.tsv';
    if ($self->roi_file_path && $self->roi_file_format) {
        # WARNING: MUST USE PERL 5.10.1
        my %refcov_params = (
            alignment_file_path => $bam_path,
            roi_file_path => $self->roi_file_path,
            roi_file_format => $self->roi_file_format,
            stats_file => $refcov_stats_file,
            print_headers => 1,
            print_min_max => 1,
        );
        unless (Genome::Model::Tools::RefCov::Standard->execute(%refcov_params)) {
            die('Failed to run RefCov Standard with parameters: '. Data::Dumper::Dumper(%refcov_params));
        }
        my $refcov_stats = Genome::Utility::IO::SeparatedValueReader->create(
            input => $refcov_stats_file,
            separator => "\t",
        );
        while (my $refcov_data = $refcov_stats->next) {
            if ($data{$bam_basename}{'RefCovMetrics'}{$refcov_data->{'name'}}) {
                die('Multiple RefCov entries found.  Probably from multiple min_depth or wingspan filters.');
            } else {
                $data{$bam_basename}{'RefCovMetrics'}{$refcov_data->{'name'}} = $refcov_data;
            }
        }
    }

    # SAMSTAT
    my %samstat_params = (
        use_version => $self->samstat_version,
        input_files => $bam_path,
    );
    unless (Genome::Model::Tools::SamStat::HtmlReport->execute(%samstat_params)) {
        die('Failed to run SamStat command with parameters: '. Data::Dumper::Dumper(%samstat_params));
    }

    # FASTQC
    my %fastqc_params = (
        use_version => $self->fastqc_version,
        input_files => $bam_path,
        report_directory => $self->output_directory,
    );
    unless (Genome::Model::Tools::Fastqc::GenerateReports->execute(%fastqc_params)) {
        die('Failed to generate FastQC reports with parameters: '. Data::Dumper::Dumper(%fastqc_params));
    }

    # ErrorRate
    my $error_rate_file = $file_basename .'-ErrorRate.tsv';
    my %error_rate_params = (
        bam_file => $bam_path,
        output_file => $error_rate_file,
    );
    if ($self->error_rate_pileup) {
        $error_rate_params{reference_fasta} = $self->reference_sequence;
        unless (Genome::Model::Tools::BioSamtools::ErrorRatePileup->execute(%error_rate_params)) {
            die('Failed to run ErrorRatePielup with parameters: '. Data::Dumper::Dumper(%error_rate_params));
        }
    } else {
        unless (Genome::Model::Tools::BioSamtools::ErrorRate->execute(%error_rate_params)) {
            die('Failed to run ErrorRatePielup with parameters: '. Data::Dumper::Dumper(%error_rate_params));
        }
    }
    
    # SUMMARY
    # TODO: First create tab-delimited(tsv) files for each txt output
    # TODO: Eventually create and xls spreadsheet or consolidated PDF report
    my $flagstat_data = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flagstat_path);
    $data{$bam_basename}{'FlagstatMetrics'} = $flagstat_data;
    my $insert_size_file = $picard_metrics_basename .'.insert_size_metrics';
    if (-e $insert_size_file) {
        my $insert_size_data = Genome::Model::Tools::Picard::CollectInsertSizeMetrics->parse_file_into_metrics_hashref($insert_size_file);
        my $insert_size_histo = Genome::Model::Tools::Picard::CollectInsertSizeMetrics->parse_metrics_file_into_histogram_hashref($insert_size_file);
        $data{$bam_basename}{'InsertSizeMetrics'} = $insert_size_data;
        $data{$bam_basename}{'InsertSizeHistogram'} = $insert_size_histo;
    }
    my $alignment_summary_file = $picard_metrics_basename .'.alignment_summary_metrics';
    if (-e $alignment_summary_file) {
        my $alignment_summary_data = Genome::Model::Tools::Picard::CollectAlignmentSummaryMetrics->parse_file_into_metrics_hashref($alignment_summary_file);
        $data{$bam_basename}{'AlignmentSummaryMetrics'} = $alignment_summary_data;
    }
    my $quality_score_file = $picard_metrics_basename .'.quality_distribution_metrics';
    if (-e $quality_score_file) {
        my $quality_score_histo = Genome::Model::Tools::Picard::QualityScoreDistribution->parse_metrics_file_into_histogram_hashref($quality_score_file);
        $data{$bam_basename}{'QualityScoreHistogram'} = $quality_score_histo;
    }
    my $quality_cycle_file = $picard_metrics_basename .'.quality_by_cycle_metrics';
    if (-e $quality_cycle_file) {
        my $quality_cycle_histo = Genome::Model::Tools::Picard::MeanQualityByCycle->parse_metrics_file_into_histogram_hashref($quality_cycle_file);
        $data{$bam_basename}{'MeanQualityByCycleHistogram'} = $quality_cycle_histo;
    }
    if (-e $picard_gc_metrics_file) {
        my $gc_data = Genome::Model::Tools::Picard::CollectGcBiasMetrics->parse_file_into_metrics_hashref($picard_gc_metrics_file);
        $data{$bam_basename}{'GcBiasMetrics'} = $gc_data;
    }
    if (-e $picard_gc_summary_file) {
        my $gc_data = Genome::Model::Tools::Picard::CollectGcBiasMetrics->parse_file_into_metrics_hashref($picard_gc_summary_file);
        $data{$bam_basename}{'GcBiasSummary'} = $gc_data;
    }
    for my $mrkdup_file (@mrkdup_files) {
        my ($mrkdup_basename,$mrkdup_dir,$mrkdup_suffix) = File::Basename::fileparse($mrkdup_file,qw/\.metrics/);
        my $mrkdup_symlink = $self->output_directory.'/'. $mrkdup_basename . $mrkdup_suffix;
        unless (-e $mrkdup_symlink) {
            symlink($mrkdup_file,$mrkdup_symlink) || die('Failed to symlink '. $mrkdup_symlink .' -> '. $mrkdup_file);
        }
        my $mrkdup_data = Genome::Model::Tools::Picard::MarkDuplicates->parse_file_into_metrics_hashref($mrkdup_symlink);
        for my $library (keys %{$mrkdup_data}) {
            if (defined($data{$bam_basename}{'MarkDuplicatesMetrics'}{$library})) {
                die('More than one MarkDuplicates file found for library '. $library .' in '. Data::Dumper::Dumper(@mrkdup_files));
            }
            $data{$bam_basename}{'MarkDuplicatesMetrics'}{$library} = $mrkdup_data->{$library};
        }
    }
    print Data::Dumper::Dumper(%data);
    return 1;
}


1;
