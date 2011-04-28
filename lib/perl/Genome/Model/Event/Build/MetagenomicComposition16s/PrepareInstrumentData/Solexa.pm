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

    unless ( $self->build->filter_reads_by_primers ) {
        $self->error_message( "Failed to filter reads by primers" );
        return;
    }

    return 1;
}

1;
