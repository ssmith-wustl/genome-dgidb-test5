package Genome::DataSource::Transcripts;

use Genome;

class Genome::DataSource::Transcripts {
    is => [ 'UR::DataSource::FileMux'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return qw(
        transcript_id
        gene_id
        transcript_start
        transcript_stop
        transcript_name
        source
        transcript_status
        strand
        chrom_name
    )
}

sub constant_values { qw(build_id) };

sub sort_order {
    return qw(
        chrom_name transcript_start transcript_id
    )
}

sub skip_first_line {
    return 0;
}

sub required_for_get { return qw( build_id) }

sub file_resolver {
    my ($build_id) = @_;

    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path = "$annotation_dir/transcripts.csv";

    return $path;
}

1;

