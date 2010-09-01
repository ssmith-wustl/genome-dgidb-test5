package Genome::DataSource::TranscriptStructures;

use Genome;

class Genome::DataSource::TranscriptStructures {
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
    has_constant => [
        quick_disconnect => { is => 'Boolean', default_value => 0 },
    ],
};

sub constant_values { [qw/chrom_name data_directory/] };
sub required_for_get { ['chrom_name','data_directory'] }
sub delimiter { "," } 
sub column_order { [ qw( 
    transcript_structure_id
    transcript_id
    structure_type
    structure_start
    structure_stop
    ordinal
    phase
    nucleotide_seq
    species 
    source 
    version
    coding_bases_before
    coding_bases_after
    cds_exons_before
    cds_exons_after
    phase_bases_before
    phase_bases_after
    )]}

sub sort_order {[qw( structure_start transcript_structure_id )] }

sub file_resolver {
    my( $chrom_name, $data_directory) = @_;

    return '/' . $data_directory . '/substructures/' . $chrom_name . '.csv';
}

1;
