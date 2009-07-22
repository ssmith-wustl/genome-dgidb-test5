package Genome::DataSource::ExternalGeneIds;

use Genome;

class Genome::DataSource::ExternalGeneIds {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton'],
};

sub delimiter {
    return ",";
}

sub column_order {
    return [ qw( egi_id gene_id id_type id_value )];
}

sub sort_order {
    return [qw( gene_id egi_id )];
}

sub skip_first_line {
    return 0;
}

sub constant_values { ['data_directory'] };
sub required_for_get { ['data_directory'] }


# All the possible locations of files
sub file_resolver {        
    my ($data_directory) = @_;
    my $path =  "$data_directory/external_gene_ids.csv";
    return $path;
}

1;

