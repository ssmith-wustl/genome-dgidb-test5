package Genome::Model::Build::MetagenomicComposition16s::AmpliconSet;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::MetagenomicComposition16s::AmpliconSet {
    is => 'UR::Object',
    has => [
        name => {
            is => 'Text',
        },
        amplicon_iterator => {
            is => 'Code',
            is_optional => 1,
        },
        classification_dir => { 
            is => 'Text',
        },
        classification_file => { 
            is => 'Text',
        },
        processed_fasta_file => { 
            is => 'Text',
        },
        processed_qual_file => { 
            is_optional => 1,
            is => 'Text',
        },
        oriented_fasta_file => { 
            is => 'Text',
        },
        oriented_qual_file => { 
            is_optional => 1,
            is => 'Text',
        },
    ],
};

sub next_amplicon {
    return $_[0]->amplicon_iterator->();
}

1;

