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
        protein_name => { 
            is => 'String' 
        },
        transcript_id => { 
            is => 'Text' 
        },
        amino_acid_seq => { 
            is => 'String' 
        },
        transcript => { #TODO, straighten out ID stuff w/ Tony
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
