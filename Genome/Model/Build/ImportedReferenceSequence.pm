package Genome::Model::Build::ImportedReferenceSequence;
#:adukes This module is used solely for importing annotation and generating sequence for genbank exons.  It needs to be expanded/combined with other reference sequence logic ( refalign models )
use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedReferenceSequence {
    is => 'Genome::Model::Build',
    has => [
        species_name => {
            via => 'model',
            to => 'species_name',
        },
    ],
};

sub sequence
{
    my $self = shift;
    my ($file, $start, $stop) = @_;

    my $f = IO::File->new();
    $f->open($file);
    my $seq = undef;
    $f->seek($start -1,0);
    $f->read($seq, $stop - $start + 1);
    $f->close();

    return $seq;
}

sub get_bases_file
{
    my $self = shift;
    my ($chromosome) = @_;


    # grab the dir here?
    my $bases_file = $self->data_directory()."/".$chromosome.".bases";

    return $bases_file;
}

1;
