package EGAP::DataSource::Exons;

use strict;
use warnings;
use EGAP;

class EGAP::DataSource::Exons {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton' ],
};

sub column_order {
    return qw/
        exon_name
        start
        end
        five_prime_overhang
        three_prime_overhang
        transcript_name
        sequence_string
    /;
}

sub sort_order {
    return ['transcript_id'];
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

