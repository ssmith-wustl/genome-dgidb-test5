package Genome::Model::Tools::Picard::CollectMultipleMetrics;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Picard::CollectMultipleMetrics {
    is  => 'Genome::Model::Tools::Picard',
    has_input => [
        input_file   => {
            is  => 'String',
            doc => 'The SAM/BAM files to run on.  File type is determined by suffix.',
        },
        output_basename  => {
            is  => 'String',
            doc => 'Basename to write output metrics files to.',
        },
        program_list => {
            is_optional => 1,
            default_value => 'CollectAlignmentSummaryMetrics,CollectInsertSizeMetrics,QualityScoreDistribution,MeanQualityByCycle',
        }, 
        reference_sequence => {
            is_optional => 1,
        },
        stop_after => {
            is  => 'Integer',
            doc => 'Stop after processing N reads, mainly for debugging. Default value: 0.',
            is_optional   => 1,
        },
        assume_sorted => {
            is => 'Boolean',
            default_value => 1,
            is_optional => 1,
        },
    ],
};

sub help_brief {
    'Takes an input BAM and reference sequence and runs one or more Picard metrics modules at the same time to cut down on I/O. Currently all programs are run with default options and fixed output extesions, but this may become more flexible in future.';
}

sub help_detail {
    return <<EOS
    For Picard documentation of this command see:
    http://picard.sourceforge.net/command-line-overview.shtml#CollectMultipleMetrics
EOS
}

sub execute {
    my $self = shift;

    my $cmd = $self->picard_path .'/CollectMultipleMetrics.jar net.sf.picard.analysis.CollectMultipleMetrics';
    $cmd   .= ' OUTPUT='. $self->output_basename  .' INPUT='. $self->input_file;
    if (defined($self->stop_after)) {
        $cmd .= ' STOP_AFTER='. $self->stop_after;
    }
    if (defined($self->reference_sequence)) {
        $cmd .= ' REFERENCE_SEQUENCE='. $self->reference_sequence;
    }
    if (defined($self->assume_sorted)) {
        if ($self->assume_sorted) {
            $cmd .= ' ASSUME_SORTED=true';
        } else {
            $cmd .= ' ASSUME_SORTED=false';
        }
    }
    my @programs = split(',',$self->program_list);
    for my $program (@programs) {
        $program =~ s/ //g;
        $cmd .= ' PROGRAM='. $program;
    }
    $self->run_java_vm(
        cmd          => $cmd,
        input_files  => [$self->input_file],
    );
    return 1;
}


1;
