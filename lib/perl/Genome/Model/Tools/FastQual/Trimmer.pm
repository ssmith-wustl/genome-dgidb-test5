package Genome::Model::Tools::FastQual::Trimmer;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::FastQual::Trimmer {
    is => 'Genome::Model::Tools::FastQual',
    is_abstract => 1,
};

sub help_brief {
    return <<HELP
    Trim fastq and fasta/quality sequences
HELP
}

sub execute {
    my $self = shift;

    my ($reader, $writer) = $self->_open_reader_and_writer;
    return if $reader or $writer;

    while ( my $sequences = $reader->read ) {
        $self->_trim($sequences);
        $writer->write($sequences);
    }

    return 1;
}

sub trim {
    my ($self, $sequences) = @_;

    unless ( $sequences and ref($sequences) eq 'ARRAY' and @$sequences ) {
        Carp::confess(
            $self->error_message("Expecting array ref of sequences, but got ".Dumper($sequences))
        );
    }

    return $self->_trim($sequences);
}

1;

