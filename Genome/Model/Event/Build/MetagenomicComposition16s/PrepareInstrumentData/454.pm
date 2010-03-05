package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454 {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData',
};

sub execute {
    my $self = shift;

    return 1;

    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }

    my $writer = $self->processed_fasta_and_qual_writer
        or return;

    my $attempted = 0;
    for my $instrument_data ( @instrument_data ) {
        my $fasta_file = $instrument_data->fasta_file;
        unless ( -s $fasta_file ) {
            $self->error_message("No fasta file found for 454 instrument data (".$instrument_data->id.")");
            return;
        }

        my $reader = $self->fasta_and_qual_reader($fasta_file);
        my $min_read_length = $self->processing_profile->amplicon_size;
        while ( my $bioseq = $reader->() ) {
            $attempted++;
            next unless $bioseq->length >= $min_read_length;
            # TODO remove primer, add to bioseq desc
            $writer->($bioseq)
                or return;
        }
    }

    $self->build->amplicons_attempted($attempted);

    return 1;
}

1;

#$HeadURL$
#$Id$
