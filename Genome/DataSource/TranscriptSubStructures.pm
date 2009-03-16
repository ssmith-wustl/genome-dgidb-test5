package Genome::DataSource::TranscriptSubStructures;

use Genome;

class Genome::DataSource::TranscriptSubStructures {
    is => 'UR::DataSource::FileMux',
};

sub constant_values { qw(build_id) };
sub required_for_get { qw( transcript_id build_id) }
sub delimiter { "\t" }
sub column_order { qw( transcript_structure_id
                       transcript_id
                       structure_type
                       structure_start
                       structure_stop
                       ordinal
                       phase
                       nucleotide_seq
               )}

sub sort_order { qw( transcript_id structure_start transcript_structure_id ) }

sub file_resolver {
    my($transcript_id, $build_id) = @_;

    my $thousand = int($transcript_id / 1000);
    $thousand .= '000';
    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path = join('/',"/$annotation_dir/transcript_sub_structure_tree",
                    $thousand,
                    $transcript_id);
    $path .= '.csv';
    return $path;
}

1;
