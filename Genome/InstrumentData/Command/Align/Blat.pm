package Genome::InstrumentData::Command::Align::Blat;

#REVIEW fdu
#limited use, removable, see REVIEW in base class Align.pm

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Align::Blat {
    is => ['Genome::InstrumentData::Command::Align'],
    has_constant => [
        aligner_name                    => { value => 'blat' },
    ],
    doc => 'align instrument data using blat (see #TODO)',
};

sub help_synopsis {
return <<EOS

EOS
}

sub help_detail {
return <<EOS

EOS
}


1;

