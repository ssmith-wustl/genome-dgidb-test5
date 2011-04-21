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

    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) { # should not happen
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }

    my %primers = $self->build->amplicon_set_names_and_primers;
    my $min_length = $self->processing_profile->amplicon_size;
    my $attempted = 0;
    for my $instrument_data ( @instrument_data ) {
        $self->status_message('PROCESSING: '.$instrument_data->id);
        unless ( $instrument_data->total_reads > 0 ) {
            $self->status_message('SKIPPING: '.$instrument_data->id.'. This instrument data does not have any reads, and will not have a fasta file.');
            next;
        }
        my $fasta_file = $instrument_data->dump_fasta_file;
        unless ( -s $fasta_file ) {
            $self->error_message('NO FASTA FILE: '.$instrument_data->id.'. This instrument data has reads, but no fasta file.');
            return;
        }

        my $reader = Genome::Model::Tools::FastQual::PhredReader->create(files => [ $fasta_file ]);
        $self->status_message('READING FASTA: '.$instrument_data->id);
        while ( my $fastas = $reader->read ) {
            my $fasta = $fastas->[0];
            $attempted++;
            # check length here
            next unless length $fasta->{seq} >= $min_length;
            my $set_name = 'none';
            my $seq = $fasta->{seq};
            REGION: for my $region ( keys %primers ) {
                for my $primer ( @{$primers{$region}} ) {
                    if ( $seq =~ s/^$primer// ) {
                        # check length again
                        $fasta->{seq} = $seq; # set new seq w/o primer
                        $set_name = $region;
                        last REGION; # go on to write 
                    }
                }
            }
            next unless length $fasta->{seq} >= $min_length;
            $fasta->{desc} = undef; # clear description
            my $writer = $self->_get_writer_for_set_name($set_name);
            $writer->write([$fasta]);
        }
        $self->status_message('DONE PROCESSING: '.$instrument_data->id);
    }

    $self->build->amplicons_attempted($attempted);

    return 1;
}

sub _get_writer_for_set_name {
    my ($self, $set_name) = @_;

    unless ( $self->{$set_name} ) {
        my $fasta_file = $self->build->processed_fasta_file_for_set_name($set_name);
        unlink $fasta_file if -e $fasta_file;
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);
        Carp::confess("Failed to create phred reader for amplicon set ($set_name)") if not $writer;
        $self->{$set_name} = $writer;
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

