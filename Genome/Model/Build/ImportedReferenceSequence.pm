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
        fasta_file => {
            is, => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'fasta_file'],
            doc => 'fully qualified fasta filename (eg /foo/bar/input.fasta)'
        },
    ],
    has_optional => [
        version => {
            is, => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'version'],
            doc => 'Identifies the version of the reference sequence.  This string may not contain spaces.'
        },
    ]
};

sub create {
    my ($class, %params) = @_;

    unless(defined($self->version) && $self->version =~ /\s/) {
        self->error_message('"version" attribute may not contain whitespace');
        return;
    }

    # Prevent the base class Build from creating an initial allocation in the wrong disk group
    my $data_directorySupplied = defined($self->data_directory);
    if(!$data_directorySupplied) {
        $self->data_directory("nill");
        $data_directorySupplied = 0;
    }

    my $self = $class->SUPER::create(%params)
        or return;

    if(!$data_directorySupplied) {
        $self->data_directory(undef);
    }

    return $self;
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
    my $bases_file = $self->data_directory()."/".$chromosome.".bases";

    $self->version = 'test';

    return $bases_file;
}

1;
