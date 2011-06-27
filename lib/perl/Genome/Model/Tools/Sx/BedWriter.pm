package Genome::Model::Tools::Sx::BedWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::BedWriter {
    is => 'Genome::Model::Tools::Sx::SeqWriter',
    has => [
        _max_files => { value => 1, },
    ],
};

sub _write {
    my ($self, $seqs) = @_;

    my $max = 10_000_000;
    for my $seq ( @$seqs ) {
        my $length = length $seq->{seq};
        my $cnt = $length / $max;
        for ( my $i = 0; $i <= $cnt; $i++ ) {
            my $end =  ($i + 1) * $max;
            if ( $end > $length ) { $end = $length; }
            ($self->_fhs)[0]->print( join( "\t", $seq->{id}, ( $i * $max), $end, ( $length > $max ? $seq->{id}.'part'.($i + 1): $seq->{id} ))."\n" );
        }
    }

    return 1;
}

1;

