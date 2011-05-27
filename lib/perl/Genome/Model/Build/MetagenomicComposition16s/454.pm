package Genome::Model::Build::MetagenomicComposition16s::454;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Model::Build::MetagenomicComposition16s::454 {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

#< prepare instrument data >#
sub prepare_instrument_data {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) { # should not happen
        $self->error_message("No instrument data found for ".$self->description);
        return;
    }

    my %primers = $self->amplicon_set_names_and_primers;
    my $min_length = $self->processing_profile->amplicon_size;
    my ($attempted, $processed, $reads_attempted, $reads_processed) = (qw/ 0 0 0 0 /);
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
            $reads_attempted++;
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
            my $writer = $self->get_writer_for_set_name($set_name);
            $writer->write([$fasta]);
            $processed++;
            $reads_processed++;
        }
        $self->status_message('DONE PROCESSING: '.$instrument_data->id);
    }

    $self->amplicons_attempted($attempted);
    $self->amplicons_processed($processed);
    $self->amplicons_processed_success( $attempted > 0 ?  sprintf('%.2f', $processed / $attempted) : 0 );
    $self->reads_attempted($reads_attempted);
    $self->reads_processed($reads_processed);
    $self->reads_processed_success( $reads_attempted > 0 ?  sprintf('%.2f', $reads_processed / $reads_attempted) : 0 );

    return 1;
}

1;

