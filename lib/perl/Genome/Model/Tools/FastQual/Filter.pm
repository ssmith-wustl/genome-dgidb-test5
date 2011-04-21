package Genome::Model::Tools::FastQual::Filter;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::FastQual::Filter {
    is  => 'Genome::Model::Tools::FastQual',
    is_abstract => 1,
};

sub help_brief {
    return <<HELP
    Filter fastq and fasta/quality sequences
HELP
}

sub execute {
    my $self = shift;

    my ($reader, $writer) = $self->_open_reader_and_writer;
    return if not $reader or not $writer;

    while ( my $seqs = $reader->read ) {
        $self->_filter($seqs) or next;
        $writer->write($seqs);
    }

    return 1;
}

sub filter {
    my ($self, $sequences) = @_;

    unless ( $sequences and ref($sequences) eq 'ARRAY' and @$sequences ) {
        Carp::confess(
            $self->error_message("Expecting array ref of sequences, but got ".Dumper($sequences))
        );
    }

    return $self->_filter($sequences);
}

1;

