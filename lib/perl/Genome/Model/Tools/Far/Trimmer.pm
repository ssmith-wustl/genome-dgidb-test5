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
       adaptor_sequence => {
            is => 'Text',
            doc => 'String (adaptor sequence) to be removed',
        },
    ],
    has_optional_input => [
        file_format => {
            is => 'Text',
            doc => 'input file format - fastq,fasta,csfastq,csfasta ; Default is fasta, output will be in the same format',
            default_value => 'fasta',
        },
         min_readlength => {
            is => 'Text',
            doc => 'minimum readlength in basepairs after adapter removal - read will be discarded otherwise ',
            default_value => '18',
        },
        max_uncalled => {
            is => 'Text',
            doc => 'nr of allowed uncalled bases in a read',
            default_value => '0',
        },
        min_overlap => {
            is => 'Text',
            doc => 'minimum required overlap of adapter and sequence in basepairs',
            default_value => '10',
        },
    ],
};


sub execute {
    my $self = shift;
    my $far_cmd = 'far --source '. $self->source .' --target ' . $self->target . ' --adapter '. $self->adaptor_sequence . ' --format '. $self->file_format. ' --nr-threads '. $self->threads.' --trim-end '.$self->trim_end.' --min-readlength '.$self->min_readlength.' --max-uncalled '.$self->max_uncalled.' --min-overlap '.$self->min_overlap;
    Genome::Sys->shellcmd(cmd=>$far_cmd);
    return 1;
}



1;
