package Genome::Model::Tools::FastQual::PhredWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::PhredWriter {
    is => 'Genome::Model::Tools::FastQual::SeqReaderWriter',
    has => [ 
        _fasta_io => { is_optional => 1, },
        _qual_io => { is_optional => 1, }, 
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @fhs = $self->_fhs;
    $self->_fasta_io($fhs[0]);
    $self->_qual_io($fhs[1]);

    return $self;
}

sub _write {
    my ($self, $seqs) = @_;

    for my $seq ( @$seqs ) { 
        $self->_write_seq($seq) or return;
        if ( $self->_qual_io ) {
            $self->_write_qual($seq) or return;
        }
    }

    return 1;
}

sub _write_seq {
    my ($self, $seq) = @_;

    my $header = '>'.$seq->{id};
    $header .= ' '.$seq->{desc} if defined $seq->{desc};
    $self->_fasta_io->print($header."\n");
    my $sequence = $seq->{seq};
    if ( defined $sequence && length($sequence) > 0 ) {
        $sequence =~ s/(.{1,60})/$1\n/g; # 60 bases per line
    } else {
        $sequence = "\n";
    }
    $self->_fasta_io->print($sequence);

    return 1;
}

sub _write_qual {
    my ($self, $seq) = @_;

    $self->_qual_io->print('>'.$seq->{id}."\n");

    my $qual_string = join(' ', map { ord($_) - 33 } split('', $seq->{qual}));
    $qual_string .= ' ';
    $qual_string =~ s/((\d\d?\s){1,25})/$1\n/g;
    $qual_string =~ s/ \n/\n/g;
    print $qual_string;
    $self->_qual_io->print($qual_string);

    return 1;
}

1;

