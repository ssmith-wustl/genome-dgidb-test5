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

    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }

    my %primers = $self->build->amplicon_set_names_and_primers;
    my $min_length = $self->processing_profile->amplicon_size;
    my $attempted = 0;
    for my $instrument_data ( @instrument_data ) {
        my $fasta_file = $instrument_data->fasta_file;
        unless ( -s $fasta_file ) {
            $self->error_message("No fasta file found for 454 instrument data (".$instrument_data->id.")");
            return;
        }

        my $reader = Genome::Utility::BioPerl->create_bioseq_reader($fasta_file); # confesses
        while ( my $fasta = $reader->next_seq ) {
            $attempted++;
            # check length here
            next unless $fasta->length >= $min_length;
            my $set_name = 'none';
            my $seq = $fasta->seq;
            REGION: for my $region ( keys %primers ) {
                for my $primer ( @{$primers{$region}} ) {
                    if ( $seq =~ s/^$primer// ) {
                        $fasta->seq($seq); # set new seq w/o primer
                        $set_name = $region;
                        last REGION; # go on to write 
                    }
                }
            }
            # and here 
            next unless $fasta->length >= $min_length;
            #print $fasta->id." $set_name ".substr($seq, 0, 17)."\n";
            my $writer = $self->_get_writer_for_set_name($set_name);
            $writer->write_seq($fasta);
        }
    }

    $self->build->amplicons_attempted($attempted);

    return 1;
}

sub _get_writer_for_set_name {
    my ($self, $set_name) = @_;

    unless ( $self->{$set_name} ) {
        my $fasta_file = $self->build->processed_fasta_file_for_set_name($set_name);
        unlink $fasta_file if -e $fasta_file;
        $self->{$set_name} = Genome::Utility::BioPerl->create_bioseq_writer(
            $fasta_file
        ); # confesses
    }

    return $self->{$set_name};
}

1;

=pod

These are the reverse primers with degeneracies taken into account.  Since the sequencing is directional and the expected amplicon lengths are: 507, 569 and 524 bp, you should not reach the other primer with 454.

If you want to look for it and remove it if it is present, here are the forward primers:
V1_V3    27Fd1    AGAGTTTGATCATGGCTCAG
V1_V3    27Fd2    AGAGTTTGATCCTGGCTCAG
V3_V6    357F    CCTACGGGAGGCAGCAG
V6_V9    U968f    AACGCGAAGAACCTTAC

#$HeadURL$
#$Id$
