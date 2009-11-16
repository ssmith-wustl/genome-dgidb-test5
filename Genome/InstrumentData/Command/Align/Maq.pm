package Genome::InstrumentData::Command::Align::Maq;

#REVIEW fdu
#limited use, removable, see REVIEW in base class Align.pm

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Align::Maq {
    is => ['Genome::InstrumentData::Command::Align'],
    has_constant => [
        aligner_name                    => { value => 'maq' },
    ],
    doc => 'align instrument data using maq (see http://maq.sourceforge.net)',
};

sub help_synopsis {
return <<EOS
genome instrument-data align maq -r NCBI-human-build36 -i 2761701954

genome instrument-data align maq -r NCBI-human-build36 -i 2761701954 -v 0.6.5

genome instrument-data align maq --reference-name NCBI-human-build36 --instrument-data-id 2761701954 --version 0.6.5

genome instrument-data align maq -i 2761701954 -v 0.6.5
EOS
}

sub help_detail {
return <<EOS
Launch the maq aligner in a standard way and produce results ready for the genome modeling pipeline.

See http://maq.sourceforge.net.
EOS
}


1;

