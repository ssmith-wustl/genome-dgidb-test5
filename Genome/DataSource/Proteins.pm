package Genome::DataSource::Proteins;

use Genome;

class Genome::DataSource::Proteins {
    is => [ 'UR::DataSource::FileMux'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return qw( protein_id transcript_id protein_name amino_acid_seq );
}

sub sort_order {
    return qw( transcript_id protein_id );
}

sub skip_first_line {
    return 0;
}

sub required_for_get { qw( transcript_id ) }

sub file_resolver {
    my($transcript_id) = @_;

    my $thousand = int($transcript_id / 1000);
    my $path = '/gscmnt/sata363/info/medseq/annotation_data/proteins/proteins_' . $thousand . ".csv";
    return $path;
}

1;

