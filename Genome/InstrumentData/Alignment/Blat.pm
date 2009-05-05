package Genome::InstrumentData::Alignment::Blat;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Alignment::Blat {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
        aligner_name => { value => 'blat' },
    ],
};


1;

