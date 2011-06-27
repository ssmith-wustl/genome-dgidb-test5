package Genome::Model::Tools::Sx::IlluminaFastqWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::IlluminaFastqWriter {
    is => 'Genome::Model::Tools::Sx::FastqWriter',
};

sub _write {
    my ($self, $seqs) = @_;
    for my $seq ( @$seqs ) { # sanger to illumina
        $seq->{qual} = join('', map { chr } map { ord($_) + 31 } split('', $seq->{qual}));
    }
    return $self->SUPER::_write($seqs);
}

1;

