
package Genome::InstrumentData::Command::Align;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Align {
    is => 'Command',
};

sub get_alignment_statistics {
    my $self = shift;
    die('get_alignment_statistics not implemented for '. $self->class);
}

1;
