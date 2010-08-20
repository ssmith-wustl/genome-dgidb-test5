package EGAP::Command::GenePredictor;

use strict;
use warnings;

class EGAP::Command::GenePredictor {
    is => 'EGAP::Command',
    has => [
        fasta_file => { 
            is => 'Path',
            is_input => 1,
            doc => 'Single fasta file to be used by prediction tool',
        },
        output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Raw output from predictor placed here',
        },
        bio_seq_feature => { 
            is => 'ARRAY', 
            is_optional => 1,
            is_output => 1,
            doc => 'Array of Bio::SeqFeature objects representing output of predictor',
        },
    ],
};

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}
 
1;
