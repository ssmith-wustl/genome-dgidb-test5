package Genome::Model::Tools::FastQual::BedWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::BedWriter {
    is => 'Genome::Model::Tools::FastQual::SeqWriter',
    has => [
        _max_files => { value => 1, },
    ],
};

sub _write {
    my ($self, $seqs) = @_;

    my $max = 10_000_000;
    for my $seq ( @$seqs ) {
        my $length = length $seq->{seq};
        for ( my $i = 0; $i <= $length; $i += $max ) {
            my $end =  $i + $max;
            if ( $end > $length ) { $end = $length; }
            ($self->_fhs)[0]->print( join( "\t", $seq->{id}, $i, $end, ( $length > $max ? $seq->{id}.'part'.(int($end / $max)): $seq->{id} ))."\n" );
        }
    }

    return 1;
}

1;

