package EGAP::Transcript;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::Transcript {
    type_name => 'transcript',
    schema => 'files',
    data_source => 'EGAP::DataSource::Transcripts',
    id_by => [
        transcript_name => { is => 'Text' },
    ],
    has => [
        coding_gene_name => { is => 'Text' },
        coding_start => { is => 'Number' },
        coding_end => { is => 'Number' },
        start => { is => 'Number' },
        end => { is => 'Number' },
        sequence_name => { is => 'Text' },
        sequence_string => { is => 'Text' },
    ],
};

sub exons {
    my ($self, $exons_file) = @_;
    confess 'Not implemented!';
    return;
}

sub coding_gene {
    my ($self, $coding_genes_file) = @_;
    confess 'Not implemented!';
    return;
}

1;
