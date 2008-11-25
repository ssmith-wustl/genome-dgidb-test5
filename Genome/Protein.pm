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
        transcript => { is => 'Genome::Transcript', id_by => 'transcript_id' },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Proteins',
};

1;

