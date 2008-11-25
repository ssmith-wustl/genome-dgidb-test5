package Genome::DataSource::Transcripts;

use Genome;

class Genome::DataSource::Transcripts {
    is => [ 'UR::DataSource::SortedCsvFile'],
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

sub sort_order {
    return qw(
        chrom_name transcript_start transcript_id
    )
}

sub skip_first_line {
    return 0;
}

sub file_list {
    return qw( /gscmnt/sata363/info/medseq/annotation_data/transcripts.csv /gscmnt/sata363/info/medseq/annotation_data/transcripts-copy.csv /gscmnt/sata363/info/medseq/annotation_data/transcripts-copy2.csv );
}

#sub server {
#    return '/gscmnt/sata363/info/medseq/annotation_data/transcripts.csv';
#}

1;

