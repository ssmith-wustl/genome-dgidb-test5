package Genome::DataSource::Genes;

use Genome;

class Genome::DataSource::Genes {
    is => [ 'UR::DataSource::SortedCsvFile'],
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

sub file_list {
    return qw( /gscmnt/sata363/info/medseq/annotation_data/genes.csv );
}

1;

