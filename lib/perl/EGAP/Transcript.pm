package EGAP::Transcript;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::Transcript {
    type_name => 'transcript',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::Transcripts',
    id_by => [
        transcript_name => { is => 'Text' },
        directory => { is => 'Path' },
    ],
    has => [
        coding_gene_name => { is => 'Text' },
        protein_name => { is => 'Text' },
        coding_start => { is => 'Number' },
        coding_end => { is => 'Number' },
        start => { is => 'Number' },
        end => { is => 'Number' },
        strand => { is => 'Text' },
        sequence_name => { is => 'Text' },
        sequence_string => { is => 'Text' },
        coding_gene => {
            calculate_from => ['directory', 'coding_gene_name'],
            calculate => q|
                my ($gene) = EGAP::CodingGene->get(directory => $directory, gene_name => $coding_gene_name);
                return $gene;
            |,
        },
        protein => {
            calculate_from => ['directory', 'protein_name'],
            calculate => q|
                my ($protein) = EGAP::Protein->get(directory => $directory, protein_name => $protein_name);
                return $protein;
            |,
        },
        exons => {
            calculate_from => ['directory', 'transcript_name'],
            calculate => q|
                my @exons = EGAP::Exon->get(directory => $directory, transcript_name => $transcript_name);
                return @exons;
            |,
        },
    ],
};

1;
