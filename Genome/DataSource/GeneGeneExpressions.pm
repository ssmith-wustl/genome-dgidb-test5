package Genome::DataSource::GeneGeneExpressions;

use Genome;

class Genome::DataSource::GeneGeneExpressions {
    is => [ 'UR::DataSource::SortedCsvFile'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return qw( expression_id gene_id );
}

sub sort_order {
    return qw( gene_id );
}

sub skip_first_line {
    return 0;
}

sub file_list {
    return qw( /gscmnt/sata363/info/medseq/annotation_data/gene_gene_expressions.csv );
}

1;

