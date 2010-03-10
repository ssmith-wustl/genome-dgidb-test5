package Genome::Model::Tools::Fasta::Dust;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Fasta::Dust {
    is => 'Genome::Model::Tools::Fasta',
    has_input => [
            fasta_file => {
                           is => 'Text',
                           doc => 'the input fasta format sequence file',
                       },
            dusted_file => {
                             is => 'Text',
                             is_optional => 1,
                             doc => 'the output fasta dusted file',
                         },
        ],
};

sub create {
    my $class = shift;
    
    my $self = $class->SUPER::create(@_);

    return $self;
}

sub execute {
    my $self = shift;
    my $fasta_file = $self->fasta_file;
    my $dusted_file = ($fasta_file=~m/(.*.)(\..*)/ and "$1.DUSTED$2");
    my $rv = system("dust $fasta_file > $dusted_file");

    return 1;
}
