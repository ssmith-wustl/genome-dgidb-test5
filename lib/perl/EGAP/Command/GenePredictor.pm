package EGAP::Command::GenePredictor;

use strict;
use warnings;

use EGAP;
use File::Temp;
use File::Basename;

class EGAP::Command::GenePredictor {
    is => 'EGAP::Command',
    is_abstract => 1,
    has => [
        fasta_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Fasta file (possibly with multiple sequences) to be used by predictor',
        },
        raw_output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Raw output of predictor goes into this directory',
        },
        egap_sequence_file => {
            is => 'Path',
            is_input => 1,
            doc => 'A file containing EGAP::Sequence objects, useful for sequence lookups',
        },
    ],
};

sub help_brief {
    return 'Abstract base class for EGAP gene prediction modules';
}

sub help_synopsis {
    return 'Abstract base class for EGAP gene prediction modules, defines a few parameters';
}

sub help_detail {
    return 'Abstract base class for EGAP gene prediction modules, defines input and output parameters';
}

1;
