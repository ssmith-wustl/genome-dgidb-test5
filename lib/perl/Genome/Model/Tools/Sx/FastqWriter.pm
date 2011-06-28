package Genome::Model::Tools::Sx::FastqWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::FastqWriter {
    is => 'Genome::Model::Tools::Sx::SeqWriter',
};

sub write {
    my ($self, $seq) = @_;

    Carp::confess('No sequence to write in fastq format!') if not $seq;

    $self->{_file}->print(
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

1;

