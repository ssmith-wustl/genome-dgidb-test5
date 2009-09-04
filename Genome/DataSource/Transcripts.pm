package Genome::DataSource::Transcripts;

use Genome;

class Genome::DataSource::Transcripts {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton'],
};

sub delimiter {
    return ",";
}

sub column_order {
    return [qw(
        transcript_id
        gene_id
        transcript_start
        transcript_stop
        transcript_name
        transcript_status
        strand
        chrom_name
        species 
        source 
        version
    )]
}

sub constant_values { [qw/ data_directory /] }; 
sub sort_order {
    return [qw(chrom_name transcript_start transcript_stop transcript_id)];
}

sub skip_first_line {
    return 0;
}

sub required_for_get { ['data_directory'] }

sub file_resolver {
    my ($data_directory) = @_;

    my $path = "$data_directory/transcripts.csv";

    return $path;
}

1;

