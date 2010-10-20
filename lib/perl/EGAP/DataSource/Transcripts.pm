package EGAP::DataSource::Transcripts;

use strict;
use warnings;
use EGAP;

class EGAP::DataSource::Transcripts {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton' ],
};

sub column_order {
    return [qw(
        transcript_name
        coding_gene_name
        coding_start
        coding_end
        start
        end
        sequence_name
        sequence_string
    )];
}

sub sort_order {
    return ['transcript_name'];
}

sub delimiter {
    return ",";
}

sub constant_values {
    return ['directory'];
}

sub skip_first_line {
    return 0;
}

sub required_for_get {
    return ['directory'];
}

sub file_resolver {
    my $directory = shift;
    return $directory . "/transcripts.csv";
}

1;

