package Genome::Model::Tools::Sx::Trimmer;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Trimmer {
    is => 'Genome::Model::Tools::Sx',
    is_abstract => 1,
};

sub help_brief {
    return 'Trim sequences';
}

sub help_synopsis {
    return help_brief();
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;

    my ($reader, $writer) = $self->_open_reader_and_writer;
    return if not $reader or not $writer;

    while ( my $seqs = $reader->read ) {
        $self->_trim($seqs);
        $writer->write($seqs);
    }

    return 1;
}

1;

