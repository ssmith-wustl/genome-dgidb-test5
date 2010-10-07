package EGAP::DataSource::Proteins;

use strict;
use warnings;
use EGAP;

class EGAP::DataSource::Proteins {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton' ],
};

sub column_order {
    return qw/
        protein_name
        internal_stops
        transcript_name
        sequence_name
        sequence_string
        cellular_localization
        cog_id
        enzymatic_pathway_id
    /;
}

sub sort_order {
    return ['transcript_name'];
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

