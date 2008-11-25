package Genome::DataSource::GeneExpressions;

use Genome;

class Genome::DataSource::GeneExpressions {
    is => [ 'UR::DataSource::SortedCsvFile'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return qw( expression_id expression_intensity dye_type probe_sequence probe_identifier tech_type detection );
}

sub sort_order {
    return qw( expression_id );
}

sub skip_first_line {
    return 0;
}

sub file_list {
    return qw( /gscmnt/sata363/info/medseq/annotation_data/gene_expressions.csv );
}

1;

