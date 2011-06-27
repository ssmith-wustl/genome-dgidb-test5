package Genome::Model::Tools::FastQual::FastqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::FastqReader {
    is => 'Genome::Model::Tools::FastQual::SeqReader',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    # 1 fh      => f from fh[0]
    # 1 fh prd  => f & r from fh[0]
    # 2 fh      => f from fh0; r from fh1
    my @fhs = $self->_fhs;
    if ( @fhs == 1 and $self->is_paired ) {
        $self->_fhs([$fhs[0], $fhs[0]]);
    }

    return $self;
}

sub _read {
    my $self = shift;

    my @seqs;
    for my $fh ( $self->_fhs ) {
        my $seq = $self->_get_seq_from_fh($fh);
        next if not $seq; 
        push @seqs, $seq;
    }

    return if not @seqs;

    if ( @seqs != $self->_fhs ) {
        Carp::confess("Have ".scalar($self->_fhs)." files but only got ".scalar(@seqs)." fastqs: ".Dumper(\@seqs));
    }

    return \@seqs;
}

sub _get_seq_from_fh {
    my ($self, $fh) = @_;

    my $line = $fh->getline;
    return if not defined $line;
    chomp $line;

    my ($id, $desc) = split(/\s+/, $line, 2);
    $id =~ s/^@//;

    my $seq = $fh->getline;
    chomp $seq; 

    $fh->getline; 
    
    my $qual = $fh->getline;
    chomp $qual;

    return {
        id => $id,
        desc => $desc,
        seq => $seq,
        qual => $qual,
    };
}

1;

