package Genome::Model::Tools::FastQual::IlluminaFastqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::IlluminaFastqReader {
    is => 'Genome::Model::Tools::FastQual::FastqReader',
};

sub _read {
    my $seqs = $_[0]->SUPER::_read;
    return if not $seqs;
    for my $seq ( @$seqs ) { # illumina to sanger
        $seq->{qual} = join('', map { chr } map { ord($_) - 31 } split('', $seq->{qual}));
    }

    return $seqs;
}

1;

