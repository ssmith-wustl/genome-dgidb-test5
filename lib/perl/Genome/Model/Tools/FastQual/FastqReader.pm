package Genome::Model::Tools::FastQual::FastqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::FastqReader {
    is => 'Genome::Model::Tools::FastQual::SeqReaderWriter',
};

sub _read {
    my $self = shift;

    my @fastqs;
    my @fhs = $self->_fhs;
    for my $fh ( @fhs ) {
        my $fastq = $self->_get_seq_from_fh($fh);
        next unless $fastq;
        push @fastqs, $fastq;
    }
    return unless @fastqs; # ok

    unless ( @fastqs == @fhs ) { # not ok??
        Carp::confess("Have ".scalar(@fhs)." files but only got ".scalar(@fastqs)." fastqs: ".Dumper(\@fastqs));
    }

    return \@fastqs;
}

sub _get_seq_from_fh {
    my ($self, $fh) = @_;

    my $line = $fh->getline;
    return if not defined $line;
    chomp $line;

    my ($id, $desc) = split(/\s/, $line, 2);
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

