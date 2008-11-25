package Genome::DataSource::Proteins;

use Genome;

class Genome::DataSource::Proteins {
    is => [ 'UR::DataSource::SortedCsvFile'],
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

sub file_list {
    return qw( /gscmnt/sata363/info/medseq/annotation_data/proteins.csv );
}

1;

