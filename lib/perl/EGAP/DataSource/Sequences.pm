package EGAP::DataSource::Sequences;

use strict;
use warnings;
use EGAP;

class EGAP::DataSource::Sequences {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton' ],
};

sub column_order {
    return [qw(
        sequence_name
        sequence_string
    )];
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

