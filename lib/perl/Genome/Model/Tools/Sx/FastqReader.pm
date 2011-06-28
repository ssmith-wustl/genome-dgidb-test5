package Genome::Model::Tools::Sx::FastqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::FastqReader {
    is => 'Genome::Model::Tools::Sx::SeqReader',
};

sub read {
    my $self = shift;

    my $line = $self->{_file}->getline;
    return if not defined $line;
    chomp $line;

    my ($id, $desc) = split(/\s+/, $line, 2);
    $id =~ s/^@//;

    my $seq = $self->{_file}->getline;
    chomp $seq; 

    $self->{_file}->getline; 
    
    my $qual = $self->{_file}->getline;
    chomp $qual;

    return {
        id => $id,
        desc => $desc,
        seq => $seq,
        qual => $qual,
    };
}

1;

