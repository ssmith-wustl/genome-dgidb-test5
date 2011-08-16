package Genome::Model::Tools::Sx::SamReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::SamReader {
    is => 'Genome::Model::Tools::Sx::SeqReader',
};

sub read {
    my $self = shift;

    my $line = $self->{_file}->getline;
    return if not defined $line;
    chomp $line;

    my @tokens = split(/\s+/, $line);

    return {
        id => $tokens[0],
        seq => $tokens[9],
        qual => $tokens[10],
    };
}

1;

