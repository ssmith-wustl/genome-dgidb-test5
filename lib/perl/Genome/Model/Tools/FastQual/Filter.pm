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

    my $reader = $self->_open_reader;
    return unless $reader;
    my $writer = $self->_open_writer;
    return unless $writer;

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Tools/Fastq/Base.pm $
#$Id: Base.pm 60817 2010-07-09 16:10:34Z ebelter $
