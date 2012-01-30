package Genome::Model::Tools::BamQc::Run;

use strict;
use warnings;

use Genome;

use Workflow;
use Workflow::Simple;

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
            # GRCh37-lite-build37
            default_value => '/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fasta',
        },
        # TODO: Add option for aligner, bwasw would require some additional tools to determine unique alignments
    ],
    has_optional_input => [
        roi_file_path => {
            is => 'Text',
            doc => 'If supplied ref-cov will run on the supplied regions of interest.',
        },
        roi_file_format => {
            is => 'Text',
            doc => 'The file format of the supplied ROI',
            valid_values => ['bam','bed'],
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
        error_rate => {
            is => 'Boolean',
            default_value => 1,
        },
        error_rate_pileup => {
            is => 'Boolean',
            default_value => 1,
        },
    ],
};

# TODO: I thought about running RefCov on the entire genome by default, but it may be computationally intensive(~several hours) depending on the genome size
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

    unless (-d $self->output_directory) {
        unless (Genome::Sys->create_directory($self->output_directory)) {
            die('Failed to create output directory: '. $self->output_directory);
        }
    }
    unless (-e $self->bam_file) {
        die('Failed to find BAM file: '. $self->bam_file);
    }
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
        if (-e $bai_file) {
            unless (symlink($bai_file,$bai_path)) {
                die('Failed to create symlink '. $bai_path .' -> '. $bai_file);
            }
        } else {
            # TODO: test if sorted
            unless (Genome::Model::Tools::Picard::BuildBamIndex->execute(
                use_version => $self->picard_version,
                maximum_permgen_memory => $self->picard_maximum_permgen_memory,
                maximum_memory => $self->picard_maximum_memory,
                input_file => $bam_path,
            )) {
                die('Failed to index BAM file: '. $bam_path);
            }
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
        # TODO: run MarkDuplicates passing the mrkdup bam file as input to the downstream steps in workflow
    }

    # PICARD METRICS
    my $picard_metrics_basename = $file_basename .'-PicardMetrics';

    # PICARD GC
    my $picard_gc_metrics_file = $file_basename .'-PicardGC_metrics.txt';
    my $picard_gc_chart_file = $file_basename .'-PicardGC_chart.pdf';
    my $picard_gc_summary_file = $file_basename .'-PicardGC_summary.txt';

    my %workflow_params = (
        picard_version => $self->picard_version,
        reference_sequence => $self->reference_sequence,
        output_directory => $self->output_directory,
        bam_file => $bam_path,
        clean_bam => 'none',
        picard_metrics_output_basename => $picard_metrics_basename,
        picard_maximum_permgen_memory => $self->picard_maximum_permgen_memory,
        picard_maximum_memory => $self->picard_maximum_memory,
        picard_max_records_in_ram => $self->picard_max_records_in_ram,
        picard_gc_metrics_file => $picard_gc_metrics_file,
        picard_gc_chart_file => $picard_gc_chart_file,
        picard_gc_summary_file => $picard_gc_summary_file,
        samstat_version => $self->samstat_version,
        fastqc_version => $self->fastqc_version,
    );
    my @output_properties = qw/
                                  picard_metrics_result
                                  picard_gc_bias_result
                                  samstat_result
                                  fastqc_result
                              /;
    if ($self->error_rate) {
        my $error_rate_file = $file_basename .'-ErrorRate.tsv';
        if (-e $error_rate_file) {
            die('Error rate file already exists at: '. $error_rate_file);
        }
        $workflow_params{error_rate_file} = $error_rate_file;
        $workflow_params{error_rate_pileup} = $self->error_rate_pileup;
        push @output_properties, 'error_rate_result';
    }
    if ($self->roi_file_path) {
        my $refcov_stats_file = $file_basename .'-RefCov_STATS.tsv';
        $workflow_params{roi_file_path} = $self->roi_file_path;
        $workflow_params{roi_file_format} = $self->roi_file_format;
        $workflow_params{refcov_stats_file} = $refcov_stats_file;
        $workflow_params{refcov_print_headers} = 1;
        $workflow_params{refcov_print_min_max} = 1;

        push @output_properties, 'refcov_result';
    }

    my @input_properties = keys %workflow_params;

    my $workflow = Workflow::Model->create(
        name => 'BamQc '. $file_basename,
        input_properties => \@input_properties,
        output_properties => \@output_properties,
    );

    $workflow->log_dir($self->output_directory);


    # PicardMetrics
    my %picard_metrics_operation_params = (
        workflow => $workflow,
        name => 'Collect Picard Metrics '. $bam_basename,
        class_name => 'Genome::Model::Tools::Picard::CollectMultipleMetrics',
        input_properties => {
            'bam_file' => 'input_file',
            'reference_sequence' => 'reference_sequence',
            'picard_metrics_output_basename' => 'output_basename',
            'picard_version' => 'use_version',
            'picard_maximum_memory' => 'maximum_memory',
            'picard_maximum_permgen_memory' => 'maximum_permgen_memory',
        },
        output_properties => {
            'result' => 'picard_metrics_result',
        },
    );
    my $picard_metrics_operation = $self->setup_workflow_operation(%picard_metrics_operation_params);
    my $max_memory = $self->picard_maximum_memory + 2;
    $picard_metrics_operation->operation_type->lsf_resource('-M '. $max_memory .'000000 -R \'select[type==LINUX64 && model!=Opteron250 && tmp>1000 && mem>'. $max_memory.'000] rusage[tmp=1000, mem='. $max_memory.'000]\'');
    
    # PicardGcBias
    my %picard_gc_bias_operation_params = (
        workflow => $workflow,
        name => 'Collect Picard G+C Bias '. $bam_basename,
        class_name => 'Genome::Model::Tools::Picard::CollectGcBiasMetrics',
        input_properties => {
            'bam_file' => 'input_file',
            'reference_sequence' => 'refseq_file',
            'clean_bam' => 'clean_bam',
            'picard_version' => 'use_version',
            'picard_maximum_memory' => 'maximum_memory',
            'picard_maximum_permgen_memory' => 'maximum_permgen_memory',
            'picard_max_records_in_ram' => 'max_records_in_ram',
            'picard_gc_metrics_file' => 'output_file',
            'picard_gc_chart_file' => 'chart_output',
            'picard_gc_summary_file' => 'summary_output',
        },
        output_properties => {
            'result' => 'picard_gc_bias_result',
        },
    );
    my $picard_gc_bias_operation = $self->setup_workflow_operation(%picard_gc_bias_operation_params);
    $picard_gc_bias_operation->operation_type->lsf_resource('-M '. $max_memory .'000000 -R \'select[type==LINUX64 && model!=Opteron250 && tmp>1000 && mem>'. $max_memory.'000] rusage[tmp=1000, mem='. $max_memory.'000]\'');
    
    # SamStat
    my %samstat_operation_params = (
        workflow => $workflow,
        name => 'SamStat Html Report '. $bam_basename,
        class_name => 'Genome::Model::Tools::SamStat::HtmlReport',
        input_properties => {
            'bam_file' => 'input_files',
            'samstat_version' => 'use_version',
        },
        output_properties => {
            'result' => 'samstat_result',
        },
    );
    $self->setup_workflow_operation(%samstat_operation_params);

    # FastQC
    my %fastqc_operation_params = (
        workflow => $workflow,
        name => 'FastQC Generate Reports '. $bam_basename,
        class_name => 'Genome::Model::Tools::Fastqc::GenerateReports',
        input_properties => {
            'bam_file' => 'input_files',
            'fastqc_version' => 'use_version',
            'output_directory' => 'report_directory',
        },
        output_properties => {
            'result' => 'fastqc_result',
        },
    );
    $self->setup_workflow_operation(%fastqc_operation_params);

    # ErrorRate
    if ($self->error_rate) {
        my %error_rate_operation_params = (
            workflow => $workflow,
            name => 'BioSamtools Error Rate '. $bam_basename,
            class_name => 'Genome::Model::Tools::BioSamtools::ErrorRate',
            input_properties => {
                'bam_file' => 'bam_file',
                'reference_sequence' => 'reference_fasta',
                'error_rate_file' => 'output_file',
                'error_rate_pileup' => 'pileup',
            },
            output_properties => {
                'result' => 'error_rate_result',
            },
        );
        $self->setup_workflow_operation(%error_rate_operation_params);
    }

    # RefCov
    # WARNING: MUST USE PERL 5.10.1
    if ($self->roi_file_path) {
        my %refcov_operation_params = (
            workflow => $workflow,
            name => 'RefCov '. $bam_basename,
            class_name => 'Genome::Model::Tools::RefCov::Standard',
            input_properties => {
                'bam_file' => 'alignment_file_path',
                'roi_file_path' => 'roi_file_path',
                'roi_file_format' => 'roi_file_format',
                'refcov_stats_file' => 'stats_file',
                'refcov_print_headers' => 'print_headers',
                'refcov_print_min_max' => 'print_min_max',
            },
            output_properties => {
                'result' => 'refcov_result',
            },
        );
        $self->setup_workflow_operation(%refcov_operation_params);
    }

    my @validation_errors = $workflow->validate;
    unless ($workflow->is_valid) {
        die('Errors encountered while validating workflow: '. join("\n", @validation_errors));
    }
    my $output = Workflow::Simple::run_workflow_lsf($workflow,%workflow_params);
    my @execution_errors = @Workflow::Simple::ERROR;
    if (@execution_errors) {
        for (@execution_errors) {
            print STDERR $_->error ."\n";
        }
        return;
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
    if ($self->roi_file_path) {
        my $refcov_stats = Genome::Utility::IO::SeparatedValueReader->create(
            input => $workflow_params{refcov_stats_file},
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

sub setup_workflow_operation {
    my $self = shift;
    my %params = @_;

    my $workflow = delete($params{'workflow'});
    my $name = delete($params{'name'});
    my $class_name = delete($params{'class_name'});
    my $input_properties = delete($params{'input_properties'});
    my $output_properties = delete($params{'output_properties'});

    my $input_connector = $workflow->get_input_connector;
    my $output_connector = $workflow->get_output_connector;

    my $operation = $workflow->add_operation(
        name => $name,
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $class_name,
        )
    );

    for my $left_property (keys %{$input_properties}) {
        my $right_property = $input_properties->{$left_property};
        $workflow->add_link(
            left_operation => $input_connector,
            left_property => $left_property,
            right_operation => $operation,
            right_property => $right_property,
        );
    }
    for my $left_property (keys %{$output_properties}) {
        my $right_property = $output_properties->{$left_property};
        $workflow->add_link(
            left_operation => $operation,
            left_property => $left_property,
            right_operation => $output_connector,
            right_property => $right_property,
        );
    }
    return $operation;
}



1;
