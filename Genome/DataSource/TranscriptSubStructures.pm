package Genome::DataSource::TranscriptSubStructures;

# NOTE - This isn't used at present.  See Genome::DataSource::CsvFileFactory

use Genome;
use UR::DataSource::SortedCsvFile;

class Genome::DataSource::TranscriptSubStructures {
    is => [ 'UR::DataSource::SortedCsvFile'],
};

sub delimiter {
    return "\t";
}

sub column_order {
    return qw(
        transcript_structure_id
        transcript_id
        structure_type
        structure_start
        structure_stop
        ordinal
        phase
        nucleotide_seq
    )
}

sub sort_order {
    return qw(
        transcript_id structure_start transcript_structure_id
    )
}

sub skip_first_line {
    return 0;
}

sub file_list {
    return qw( /gscmnt/sata363/info/medseq/annotation_data/transcript_sub_structures.csv );
    #return '/gscmnt/sata363/info/medseq/annotation_data/transcript_sub_structure_1.csv';
    #return '/home/archive/abrummet/transcript_sub_structures.csv';
    #return '/home/archive/abrummet/transcript_sub_structure_1.csv';
}

1;

