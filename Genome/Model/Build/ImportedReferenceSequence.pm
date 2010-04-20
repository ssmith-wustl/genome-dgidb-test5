package Genome::Model::Build::ImportedReferenceSequence;
#:adukes This module is used solely for importing annotation and generating sequence for genbank exons.  It needs to be expanded/combined with other reference sequence logic ( refalign models )
use strict;
use warnings;

use Genome;
use POSIX;

class Genome::Model::Build::ImportedReferenceSequence {
    is => 'Genome::Model::Build',
    has => [
        species_name => {
            via => 'model',
            to => 'species_name',
        },
        fasta_file => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'fasta_file', value_class_name => 'UR::Value'],
            doc => 'fully qualified fasta filename (eg /foo/bar/input.fasta)'
        },
    ],
    has_optional => [
        version => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'version', value_class_name => 'UR::Value'],
            doc => 'Identifies the version of the reference sequence.  This string may not contain spaces.'
        },
        prefix => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'prefix', value_class_name => 'UR::Value'],
            doc => 'The source of the sequence (such as NCBI).  May not contain spaces.'
        }
    ]
};

sub calculate_estimated_kb_usage {
    my $self = shift;
    my $fastaSize = -s $self->fasta_file;
    if(defined($fastaSize) && $fastaSize > 0)
    {
        $fastaSize = POSIX::ceil($fastaSize * 3 / 1024);
    }
    else
    {
        $fastaSize = $self->SUPER::calculate_estimated_kb_usage();
    }
    return $fastaSize;
}

sub sequence {
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

sub get_bases_file {
    my $self = shift;
    my ($chromosome) = @_;

    # grab the dir here?
    my $bases_file = $self->data_directory . "/" . $chromosome.".bases";

    return $bases_file;
}

1;
