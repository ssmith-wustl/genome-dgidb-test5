package Genome::InstrumentData::Command::Align::Imported;

use strict;
use warnings;

use Genome;

# This sub-class is probably not necessary because of imported
# instrument data has already aligned before.

class Genome::InstrumentData::Command::Align::Imported {
    is => ['Genome::InstrumentData::Command::Align'],
    has_constant => [
        aligner_name => { value => 'imported' },
    ],
    doc => 'Align imported instrument data',
};

sub help_synopsis {
return <<EOS
FIXME
EOS
}

sub help_detail {
return <<EOS
TBA
EOS
}


1;

