package Genome::DataSource::TranscriptSubStructures;

use Genome;

class Genome::DataSource::TranscriptSubStructures {
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub constant_values { ['data_directory'] };
sub required_for_get { ['transcript_id','data_directory'] }
sub delimiter { "," } 
sub column_order { [ qw( transcript_structure_id
                       transcript_id
                       structure_type
                       structure_start
                       structure_stop
                       ordinal
                       phase
                       nucleotide_seq
               )]}

sub sort_order {[qw( transcript_id structure_start transcript_structure_id )] }

sub file_resolver {
    my( $composite_id, $data_directory) = @_;

    my $meta = Genome::Transcript->__meta__;
    my ($chrom, $position, $transcript_id) = $meta->resolve_ordered_values_from_composite_id($composite_id);

    my $thousand = int($transcript_id / 1000);
    $thousand .= '000';
    my $path = join('/',"/$data_directory/transcript_sub_structure_tree",
        $thousand,
        $transcript_id);
    $path .= '.csv';

    return $path;
}

1;
