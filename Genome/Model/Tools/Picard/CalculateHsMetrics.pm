package Genome::Model::Tools::Picard::CalculateHsMetrics;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Picard::CalculateHsMetrics {
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
        bait_intervals  => {
            is  => 'String',
            doc => 'An interval list file that contains the locations of the baits used.',
        },
        target_intervals => {
            is  => 'String',
            doc => 'An interval list file that contains the locations of the targets',
        },
    ],
};

sub help_brief {
    'Calculates a set of Hybrid Selection specific metrics from an aligned SAM or BAM file.';
}

sub help_detail {
    return <<EOS
    For Picard documentation of this command see:
    http://picard.sourceforge.net/command-line-overview.shtml#CalculateHsMetrics
EOS
}

sub execute {
    my $self = shift;

    my $cmd = $self->picard_path .'/CalculateHsMetrics.jar net.sf.picard.analysis.directed.CalculateHsMetrics OUTPUT='. $self->output_file
        .' INPUT='. $self->input_file .' BAIT_INTERVALS='. $self->bait_intervals .' TARGET_INTERVALS='. $self->target_intervals;

    $self->run_java_vm(
        cmd          => $cmd,
        input_files  => [$self->input_file, $self->bait_intervals, $self->target_intervals],
        output_files => [$self->output_file],
        skip_if_output_is_present => 0,
    );
    return 1;
}


1;
