package Genome::DataSource::ExternalGeneIds;

use Genome;

class Genome::DataSource::ExternalGeneIds {
    is => [ 'UR::DataSource::FileMux'],
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

sub constant_values { qw(build_id) };
sub required_for_get { qw(build_id ) }


# All the possible locations of files
sub file_resolver {        
    my ($build_id) = @_;
    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path =  "$annotation_dir/external_gene_ids.csv";
    return $path;
}

1;

