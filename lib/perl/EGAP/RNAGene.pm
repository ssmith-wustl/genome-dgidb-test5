package EGAP::RNAGene;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::RNAGene {
    type_name => 'rna gene',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::RNAGenes',
    id_by => [
        gene_name => { is => 'Text' },
    ],
    has => [
        file_path => { is => 'Path' },
        description => { is => 'Text' },
        start => { is => 'Number' },
        end => { is => 'Number' },
        strand => { is => 'Number' },
        source => { is => 'Text' },
        score => { is => 'Number' },
        sequence_name => { is => 'Text' },
        sequence_string => { is => 'Text' },
    ],
    has_optional => [
        accession => { is => 'Text' },
        product => { is => 'Text' },
        codon => { is => 'Text' },
    ],
};

sub sequence {
    my ($self, $sequence_file) = @_;
    confess 'Not implemented!';
    return;
}

1;
