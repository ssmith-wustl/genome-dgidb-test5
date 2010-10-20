package EGAP::Exon;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::Exon {
    type_name => 'exon',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::Exons',
    id_by => [
        exon_name => { is => 'Text' },
        directory => { is => 'Path' },
    ],
    has => [
        start => { is => 'Number' },
        end => { is => 'Number' },
        strand => { is => 'Text' },
        score => { is => 'Text' },
        five_prime_overhang => { is => 'Number' },
        three_prime_overhang => { is => 'Number' },
        transcript_name => { is => 'Text' },
        gene_name => { is => 'Text' },
        sequence_name => { is => 'Text' },
        sequence_string => { is => 'Text' },
    ],
};

1;
