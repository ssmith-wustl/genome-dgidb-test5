package Genome::Protein;

use strict;
use warnings;

use Genome;

class Genome::Protein {
    type_name => 'genome protein',
    table_name => 'PROTEIN',
    id_by => [
        protein_id => { is => 'Text' },
        species => { is => 'varchar',
            is_optional => 1,
        },
        source => { is => 'VARCHAR',
            is_optional => 1,
        },
        version => { is => 'VARCHAR',
            is_optional => 1,
        },
    ],
    has => [
        protein_name => { 
            is => 'String' 
        },
        transcript_id => { 
            is => 'Text' 
        },
        amino_acid_seq => { 
            is => 'String' 
        },
        transcript => { 
            is => 'Genome::Transcript', 
            id_by => 'transcript_id' 
        },
        data_directory => {
                    is => "Path",
                    },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Proteins',
};

1;

#TODO
=pod
=cut
