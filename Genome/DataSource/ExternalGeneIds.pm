package Genome::DataSource::ExternalGeneIds;

use Genome;

class Genome::DataSource::ExternalGeneIds {
    is => [ 'UR::DataSource::File'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return qw( egi_id gene_id id_type id_value );
}

sub sort_order {
    return qw( gene_id egi_id );
}

sub skip_first_line {
    return 0;
}


# All the possible locations of files
sub file_list {        
    return qw( /gscmnt/sata363/info/medseq/annotation_data/external_gene_ids.csv );
}

1;

