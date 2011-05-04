package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData',
};

sub execute {
    my $self = shift;

    if ( not $self->build->prepare_instrument_data ) {
        $self->error_message('Failed to prepare instrument data for '.$self->build->description);
        return;
    }

    return 1;
}

1;

