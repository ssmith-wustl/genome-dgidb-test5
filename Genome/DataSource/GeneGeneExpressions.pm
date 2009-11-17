# Review gsanders: This can be removed and has not been used for some time

package Genome::DataSource::GeneGeneExpressions;

use Genome;

class Genome::DataSource::GeneGeneExpressions {
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return [qw( expression_id gene_id )];
}

sub sort_order {
    return ['gene_id'] ;
}

sub skip_first_line {
    return 0;
}

sub constant_values { ['build_id'] };
sub required_for_get { ['gene_id','build_id'] }

sub file_resolver {
    my($gene_id, $build_id) = @_;

    my $thousand = int($gene_id / 1000);
    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path = "$annotation_dir/gene_gene_expressions/gene_gene_expressions_" . $thousand . ".csv";
    return $path;
}

1;

