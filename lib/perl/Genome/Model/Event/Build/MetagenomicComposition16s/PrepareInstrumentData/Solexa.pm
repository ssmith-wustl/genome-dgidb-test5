package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Solexa {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData',
};

sub bsub {
    return "-R 'span[hosts=1] select[type=LINUX64]'";
}

sub execute {
    my $self = shift;

    unless ( $self->build->prepare_instrument_data ) {
        $self->error_message('Failed to prepare instrument data for '.$self->build->description);
        return;
    }

    return 1;
}

1;

