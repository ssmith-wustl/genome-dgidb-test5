package EGAP::DataSource::RNAGenes;

use strict;
use warnings;
use EGAP;

class EGAP::DataSource::RNAGenes {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton' ],
};

sub column_order {
    return qw/
        sequence_name
        gene_name
        description
        start
        end
        strand
        source
        score
        sequence_string
        accession
        product
        codon
    /;
}

sub sort_order {
    return ['sequence_name'];
}

sub delimiter {
    return ",";
}

sub constant_values {
    return ['file_path'];
}

sub skip_first_line {
    return 0;
}

sub required_for_get {
    return ['file_path'];
}

sub file_resolver {
    my $file_path = shift;
    return $file_path;
}

1;

