package Genome::DataSource::Genes;

use Genome;

class Genome::DataSource::Genes {
    is => 'UR::DataSource::FileMux',
};

sub delimiter {
    return "\t";
}

sub column_order {
    return qw( gene_id hugo_gene_name strand );
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
    my $path = '/gscmnt/sata363/info/medseq/annotation_data/genes_' . $thousand . ".csv";
    return $path;
}


1;

