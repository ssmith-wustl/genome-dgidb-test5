package Genome::Model::Build::MetagenomicComposition16s::Solexa;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Model::Build::MetagenomicComposition16s::Solexa {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

#< prepare instrument data >#
sub prepare_instrument_data {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message( "No instrument exists for ".$self->description );
        return;
    }

    my $min_length = $self->processing_profile->amplicon_size;
    my ($attempted, $processed, $reads_attempted, $reads_processed) = (qw/ 0 0 0 /);

    my $fasta_file = $self->processed_fasta_file_for_set_name('');
    my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);

    for my $inst_data ( @instrument_data ) {
        my @fastq_files = $self->fastqs_from_solexa( $inst_data );
        my $reader = Genome::Model::Tools::FastQual::FastqReader->create( files => \@fastq_files );

        SEQ: while ( my $fastqs = $reader->read ) {
            for my $fastq ( @$fastqs ) {
                $attempted++;
                $reads_attempted++;
                next SEQ unless length $fastq->{seq} >= $min_length;
                $fastq->{desc} = undef;
                $processed++;
                $reads_processed++;
            }
            $writer->write( $fastqs );
        }
        $self->status_message('DONE PROCESSING: '.$inst_data->id);
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

