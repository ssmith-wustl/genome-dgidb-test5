package EGAP::CodingGene;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::CodingGene {
    type_name => 'coding gene',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::CodingGenes',
    id_by => [
        gene_name => { is => 'Text' },
    ],
    has => [
        file_path => { is => 'Path' },
        fragment => { is => 'Boolean' },
        internal_stops => { is => 'Boolean' },
        missing_start => { is => 'Boolean' },
        missing_stop => { is => 'Boolean' },
        source => { is => 'Text' },
        score => { is => 'Number' },
        strand => { is => 'Number' },
        sequence_name => { is => 'Number' },
        sequence_string => { is => 'Text' },
        start => { is => 'Number' },
        end => { is => 'Number' },
    ],
};

sub transcripts {
    my ($self, $transcripts_file) = @_;
    confess 'Not implemented!';
    return;
}

sub sequence {
    my ($self, $sequence_file) = @_;
    confess 'Not implemented!';
    return;
}

1;
