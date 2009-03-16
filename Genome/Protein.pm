package Genome::Protein;

use strict;
use warnings;

use Genome;

class Genome::Protein {
    type_name => 'genome protein',
    table_name => 'PROTEIN',
    id_by => [
        protein_id => { is => 'NUMBER' },
    ],
    has => [
        protein_name => { is => 'String' },
        transcript_id => { is => 'Number' },
        amino_acid_seq => { is => 'String' },
        transcript => {
            calculate_from => [qw/ transcript_id build_id/],
            calculate => q|
                Genome::Transcript->get(transcript_id => $transcript_id, build_id => $build_id);
            |,
        },
        build => {
                    is => "Genome::Model::Build",
                    id_by => 'build_id',
                    },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Proteins',
};

1;

