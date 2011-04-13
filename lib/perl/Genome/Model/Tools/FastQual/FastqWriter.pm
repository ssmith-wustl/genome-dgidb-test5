package Genome::Model::Tools::FastQual::FastqWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::FastqWriter {
    is => 'Genome::Model::Tools::FastQual::SeqReaderWriter',
    has => [
        _write_strategy => { is_optional => 1, },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    $self->_write_strategy( $self->files == 1 ? '_collate' : '_separate' );

    return $self;
}

sub _write {
    #my ($self, $fastqs) = @_;
    my $write_strategy = $_[0]->_write_strategy;
    return $_[0]->$write_strategy($_[1]);
}
    
sub _print_seq_to_fh {
    my ($self, $fh, $seq) = @_;

    $fh->print(
        join(
            "\n",
            '@'.$seq->{id}.( defined $seq->{desc} ? ' '.$seq->{desc} : '' ),
            $seq->{seq},
            '+',
            $seq->{qual},
        )."\n"
    );

    return 1;
}

sub _separate {
    my ($self, $fastqs) = @_;

    for my $i (0..1) {
        $self->_print_seq_to_fh(($self->_fhs)[$i], $fastqs->[$i])
            or Carp::confess("Can't write fastq: ".Dumper($fastqs->[$i]));
    }

    return 1;
}

sub _collate {
    my ($self, $fastqs)  = @_;

    my $fh = ($self->_fhs)[0];
    for my $fastq ( @$fastqs ) {
        $self->_print_seq_to_fh($fh, $fastq)
            or Carp::confess("Can't write fastq: ".Dumper($fastq));
    }

    return 1;
}

1;

