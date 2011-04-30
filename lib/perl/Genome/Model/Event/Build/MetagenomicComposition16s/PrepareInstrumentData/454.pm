package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454 {
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

=pod

These are the reverse primers with degeneracies taken into account.  Since the sequencing is directional and the expected amplicon lengths are: 507, 569 and 524 bp, you should not reach the other primer with 454.

If you want to look for it and remove it if it is present, here are the forward primers:
V1_V3    27Fd1    AGAGTTTGATCATGGCTCAG
V1_V3    27Fd2    AGAGTTTGATCCTGGCTCAG
V3_V6    357F    CCTACGGGAGGCAGCAG
V6_V9    U968f    AACGCGAAGAACCTTAC

