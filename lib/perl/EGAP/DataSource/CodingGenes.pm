package EGAP::DataSource::CodingGenes;

use strict;
use warnings;
use EGAP;

class EGAP::DataSource::CodingGenes {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton' ],
};

sub column_order {
    return [qw(
        gene_name
        fragment
        internal_stops
        missing_start
        missing_stop
        source
        strand
        sequence_name
        start
        end
    )];
}

sub sort_order {
    return ['gene_name'];
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

