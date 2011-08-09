package Genome::Model::Tools::Far::Trimmer;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Far::Trimmer {
    is => ['Genome::Model::Tools::Far::Base'],
    has_input => [
        source => {
            is => 'Text',
            doc => 'Input file containing reads to be trimmed',
        },
        target => {
            is => 'Text',
            doc => 'Output file containing trimmed reads',
        },
    ],
    has_optional_input => [
        source2 => {
            is => 'Text',
            doc => 'Second input file containing reads to be trimmed',
        },
        params => {
            is => 'Text',
            doc => 'A list of params to be APPENDED to the command line.',
        },
        adaptor_sequence => {
            is => 'Text',
            doc => 'String (adaptor sequence) to be removed',
        },
        file_format => {
            is => 'Text',
            doc => 'input file format, output will be in the same format',
            valid_values => ['fastq','fasta','csfastq','csfasta'],
            default_value => 'fastq',
        },
        min_read_length => {
            is => 'Text',
            doc => 'minimum readlength in basepairs after adapter removal - read will be discarded otherwise. far default:18',
        },
        max_uncalled => {
            is => 'Text',
            doc => 'nr of allowed uncalled bases in a read. far default: 0',
        },
        min_overlap => {
            is => 'Text',
            doc => 'minimum required overlap of adapter and sequence in basepairs. far default: 10',
        },
        threads => {
            is            => 'Text',
            doc           => 'Number of threads to use. far default: 1',
        },
        trim_end => {
            is          => 'Text',
            doc         => 'Decides on which end adapter removal is performed. far default: right',
            valid_values => ['right','left','any','left_tail','right_tail'],
        },
        far_output => {
            is => 'Text',
            doc => 'Redirect the stdout from the far command.',
        },
    ],
};


sub execute {
    my $self = shift;
    my $far_cmd = $self->far_path .' --source '. $self->source .' --target ' . $self->target;
    if (defined($self->source2)) {
        $far_cmd .= ' --source2 '. $self->source2;
    }
    if (defined($self->adaptor_sequence)) {
        $far_cmd .= ' --adapter '. $self->adaptor_sequence;
    }
    if (defined($self->file_format)) {
        $far_cmd .= ' --format '. $self->file_format;
    }
    if (defined($self->threads)) {
        $far_cmd .= ' --nr-threads '. $self->threads;
    }
    if (defined($self->trim_end)) {
        $far_cmd .= ' --trim-end '.$self->trim_end;
    }
    if (defined($self->min_read_length)) {
        $far_cmd .= ' --min-readlength '.$self->min_read_length
    }
    if (defined($self->max_uncalled)) {
        $far_cmd .= ' --max-uncalled '.$self->max_uncalled;
    }
    if (defined($self->min_overlap)) {
        $far_cmd .= ' --min-overlap '.$self->min_overlap;
    }
    if (defined($self->params)) {
        $far_cmd .= ' '. $self->params;
    }
    my @output_files;
    push @output_files, $self->target;
    if (defined($self->far_output)) {
        $far_cmd .= ' > '. $self->far_output;
        push @output_files, $self->far_output;
    }
    Genome::Sys->shellcmd(
        cmd => $far_cmd,
        input_files => [$self->source],
        output_files => \@output_files,
        skip_if_output_is_present => 0,
    );
    return 1;
}



1;
