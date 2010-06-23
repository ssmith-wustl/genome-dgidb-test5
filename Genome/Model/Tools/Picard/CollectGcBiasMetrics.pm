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
            doc => 'The SAM/BAM files to run on.  File type is determined by suffix.',
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
    ],
};

sub help_brief {
    'Tool to collect GC bias metrics from a SAM/BAM file.';
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

    my $cmd = $self->picard_path .'/CollectGcBiasMetrics.jar net.sf.picard.analysis.CollectGcBiasMetrics';
    $cmd   .= ' OUTPUT='. $self->output_file  .' INPUT='. $self->input_file .' REFERENCE_SEQUENCE='. $self->refseq_file;
    
    my $out_dir = dirname $self->output_file;

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
        input_files  => [$self->input_file],
        #output_files => [$self->output_file, $chart],
        skip_if_output_is_present => 0,
    );
    return 1;
}


1;
