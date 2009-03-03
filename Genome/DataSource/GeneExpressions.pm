package Genome::DataSource::GeneExpressions;

use Genome;

class Genome::DataSource::GeneExpressions {
    is => 'UR::DataSource::FileMux',
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

sub required_for_get { qw( expression_id ) }

sub file_resolver {
    my($expression_id) = @_;

    my $thousand = int($expression_id / 1000);
    my $path = '/gscmnt/sata363/info/medseq/annotation_data/gene_expressions/gene_expressions_' . $thousand . ".csv";
    return $path;
}

1;

