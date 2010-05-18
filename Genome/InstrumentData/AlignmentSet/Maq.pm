package Genome::InstrumentData::AlignmentSet::Maq;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::AlignmentSet::Maq {
    is => ['Genome::InstrumentData::AlignmentSet'],
    has_constant => [
                     aligner_name => { value => 'maq' },
    ],
};
