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
        transcript => {
            calculate_from => ['directory', 'transcript_name'],
            calculate => q|
                my ($transcript) = EGAP::Transcript->get(directory => $directory, transcript_name => $transcript_name);
                return $transcript;
            |,
        },
        coding_gene => {
            calculate_from => ['directory', 'gene_name'],
            calculate => q|
                my ($gene) = EGAP::CodingGene->get(directory => $directory, gene_name => $gene_name);
                return $gene
            |,
        },
    ],
};

1;
