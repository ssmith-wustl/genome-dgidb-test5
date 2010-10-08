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

