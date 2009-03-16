package Genome::DataSource::Variations;

use Genome;

class Genome::DataSource::Variations{
    is => 'UR::DataSource::FileMux',
};

sub delimiter {
    return "\t";
}

sub column_order {

return
qw(
variation_id
external_variation_id
allele_string
variation_type
chrom_name
start
stop
pubmed_id
);
}

sub sort_order {
    return qw( start );
}

sub skip_first_line {
    return 0;
}

sub constant_values { qw( build_id ) };
sub required_for_get { qw( chrom_name build_id) }

sub file_resolver {
    my($chrom_name, $build_id) = @_;

    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path = "$annotation_dir/variations/variations_" . $chrom_name . ".csv";
    return $path;
}

1;

