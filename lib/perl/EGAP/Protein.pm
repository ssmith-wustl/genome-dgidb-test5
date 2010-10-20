package EGAP::Protein;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::Protein {
    type_name => 'protein',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::Proteins',
    id_by => [
        protein_name => { is => 'Text' },
        directory => { is => 'Path' },
    ],
    has => [
        internal_stops => { is => 'Boolean' },
        fragment => { is => 'Boolean' },
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
                return $gene;
            |,
        },
    ],
    has_optional => [
        cellular_localization => { is => 'Text' },
        cog_id => { is => 'Text' },
        enzymatic_pathway_id => { is => 'Text' },
    ],
};

1;
