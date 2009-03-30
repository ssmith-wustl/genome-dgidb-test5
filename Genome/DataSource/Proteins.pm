package Genome::DataSource::Proteins;

use Genome;

class Genome::DataSource::Proteins {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return [qw( protein_id transcript_id protein_name amino_acid_seq )];
}

sub sort_order {
    return [qw( transcript_id protein_id )];
}

sub skip_first_line {
    return 0;
}

sub constant_values { ['build_id'] };
sub required_for_get { [qw( transcript_id build_id)] }

sub file_resolver {
    my($transcript_id, $build_id) = @_;

    my $thousand = int($transcript_id / 1000);
    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path = "$annotation_dir/proteins/proteins_" . $thousand . ".csv";
    return $path;
}

1;

