# Review gsanders: This can be removed and has not been used for some time

package Genome::DataSource::GeneExpressions;

use Genome;

class Genome::DataSource::GeneExpressions {
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return [ qw( expression_id expression_intensity dye_type probe_sequence probe_identifier tech_type detection )];
}

sub sort_order {
    return ['expression_id'];
}

sub skip_first_line {
    return 0;
}

sub constant_values { ['build_id'] };
sub required_for_get { ['expression_id', 'build_id'] }

sub file_resolver {
    my($expression_id,$build_id) = @_;

    my $thousand = int($expression_id / 1000);
    
    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path = "$annotation_dir/gene_expressions/gene_expressions_" . $thousand . ".csv";
    return $path;
}

1;

