package Genome::Model::Tools::FastQual::PhredWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::PhredWriter {
    is => 'Genome::Model::Tools::FastQual::SeqWriter',
};

sub _write {
    my ($self, $seqs) = @_;

    my @fhs = $self->_fhs;
    for my $seq ( @$seqs ) { 
        $self->_write_seq($fhs[0], $seq) or return;
        if ( $fhs[1]) {
            $self->_write_qual($fhs[1], $seq) or return;
        }
    }

    return 1;
}

sub _write_seq {
    my ($self, $fh, $seq) = @_;

    my $header = '>'.$seq->{id};
    $header .= ' '.$seq->{desc} if defined $seq->{desc};
    $fh->print($header."\n");
    my $sequence = $seq->{seq};
    if ( defined $sequence && length($sequence) > 0 ) {
        $sequence =~ s/(.{1,60})/$1\n/g; # 60 bases per line
    } else {
        $sequence = "\n";
    }
    $fh->print($sequence);

    return 1;
}

sub _write_qual {
    my ($self, $fh, $seq) = @_;

    $fh->print('>'.$seq->{id}."\n");

    my $qual_string = join(' ', map { ord($_) - 33 } split('', $seq->{qual}));
    $qual_string .= ' ';
    $qual_string =~ s/((\d\d?\s){1,25})/$1\n/g;
    $qual_string =~ s/ \n/\n/g;
    $fh->print($qual_string);

    return 1;
}

1;

