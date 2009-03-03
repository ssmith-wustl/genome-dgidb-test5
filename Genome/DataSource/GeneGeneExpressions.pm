package Genome::DataSource::GeneGeneExpressions;

use Genome;

class Genome::DataSource::GeneGeneExpressions {
    is => 'UR::DataSource::FileMux',
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

sub required_for_get { qw( gene_id ) }

sub file_resolver {
    my($gene_id) = @_;

    my $thousand = int($gene_id / 1000);
    my $path = '/gscmnt/sata363/info/medseq/annotation_data/gene_gene_expressions/gene_gene_expressions_' . $thousand . ".csv";
    return $path;
}

1;

