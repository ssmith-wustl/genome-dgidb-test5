package EGAP::Sequence;

use strict;
use warnings;

use EGAP;


class EGAP::Sequence {
    type_name => 'dna sequence',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::Sequences',
    id_by => [
        sequence_name   => { is => 'Text' },
    ],
    has => [
        file_path => { is => 'Path' },
        sequence_string => { is => 'Text' },
    ],
};

sub coding_genes {
    my ($self, $coding_genes_file) = @_;
    confess 'Not implemented!';
    return;
}

sub rna_genes {
    my ($self, $rna_genes_file) = @_;
    confess 'Not implemtned!';
    return;
}

1;
