package Genome::Model::Tools::Picard::CollectGcBiasMetrics;

use strict;
use warnings;

use Genome;
use File::Basename;


class Genome::Model::Tools::Picard::CollectGcBiasMetrics {
    is  => 'Genome::Model::Tools::Picard',
    has_input => [
        input_file   => {
            is  => 'String',
            doc => 'The BAM file to run on.',
        },
        output_file  => {
            is  => 'String',
            doc => 'The output metrics file',
        },
        refseq_file  => {
            is  => 'String',
            doc => 'The reference sequence file',
        },
        chart_output => {
            is  => 'String',
            doc => 'The PDF file to render the chart to. Default is GC_bias_chart.pdf in output_file dir',
            is_optional => 1,
        },
        summary_output => {
            is  => 'String',
            doc => 'The text file to write summary metrics to. Default is GC_bias_summary.txt',
            is_optional => 1,
        },
        window_size  => {
            is  => 'Integer',
            doc => 'The size of windows on the genome that are used to bin reads. Default value: 100',
            default_value => 100,
            is_optional   => 1,
        },
        min_genome_fraction => {
            is  => 'Number',
            doc => 'For summary metrics, exclude GC windows that include less than this fraction of the genome. Default value: 1.0E-5.',
            default_value => '1.0E-5',
            is_optional   => 1,
        },
        max_records_in_ram => {
            is => 'Integer',
            doc => 'The number of alignment records to store in RAM before spilling to disk.',
            default_value => 500000,
            is_optional => 1,
        },
        clean_bam => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Flag to run G:M:T:BioSamtools::CleanBam to remove reads that align beyond the end of chromosomes.(ie. BWA 0.5.5 and prior)',
        },
        clean_bam_summary => {
            is => 'Text',
            is_optional => 1,
            doc => 'A file path to store CleanBam metrics.',
        },
    ],
};

sub help_brief {
    'Tool to collect GC bias metrics from a BAM file.';
}

sub help_detail {
    return <<EOS
    For Picard documentation of this command see:
    http://picard.sourceforge.net/command-line-overview.shtml#CollectGcBiasMetrics
EOS
}

sub execute {
    my $self = shift;

    for my $type qw(input refseq) {
        my $property_name = $type.'_file';
        unless ($self->$property_name and -s $self->$property_name) {
            $self->error_message("$property_name is invalid");
            return;
        }
    }
    my $out_dir = dirname $self->output_file;
    my $input_file = $self->input_file;
    if ($self->clean_bam) {
        my $basename = basename($self->output_file,qw/\.bam/);
        my $clean_bam_file = Genome::Utility::FileSystem->create_temp_file_path($basename .'_clean_bam.bam');
        unless (Genome::Model::Tools::BioSamtools::CleanBam->execute(
            input_bam_file => $self->input_file,
            output_bam_file => $clean_bam_file,
            summary_output_file => $self->clean_bam_summary,
        )) {
            die('Failed to run G:M:T:BioSamtools::CleanSam on BAM file: '. $self->input_file);
        }
        $input_file = $clean_bam_file;
    }
    my $cmd = $self->picard_path .'/CollectGcBiasMetrics.jar net.sf.picard.analysis.CollectGcBiasMetrics';
    $cmd   .= ' OUTPUT='. $self->output_file  .' INPUT='. $input_file .' REFERENCE_SEQUENCE='. $self->refseq_file;

    my $chart = $self->chart_output   || $out_dir . '/GC_bias_chart.pdf';
    my $sum   = $self->summary_output || $out_dir . '/GC_bias_summary.txt';

    $cmd .= ' CHART_OUTPUT='.$chart .' SUMMARY_OUTPUT='.$sum;

    if ($self->window_size) {
        $cmd .= ' WINDOW_SIZE=' . $self->window_size;
    }
    if ($self->min_genome_fraction) {
        $cmd .= ' MINIMUM_GENOME_FRACTION='. $self->min_genome_fraction;
    }

    $self->run_java_vm(
        cmd          => $cmd,
        input_files  => [$input_file],
        #output_files => [$self->output_file, $chart],
        skip_if_output_is_present => 0,
    );
    return 1;
}


1;
