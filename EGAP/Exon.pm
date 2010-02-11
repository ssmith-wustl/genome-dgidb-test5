package EGAP::Exon;

use strict;
use warnings;

use EGAP;


class EGAP::Exon {
    type_name => 'exon',
    table_name => 'EXON',
    id_sequence_generator_name => 'exon_id_seq', 
    id_by => [
        exon_id => { is => 'NUMBER', len => 12 },
    ],
    has => [
        end         => { is => 'NUMBER', len => 10, column_name => 'SEQ_END' },
        start       => { is => 'NUMBER', len => 10, column_name => 'SEQ_START' },
        sequence_string => { is => 'BLOB', len => 2147483647 },
        transcript      => { is => 'EGAP::Transcript', id_by => 'transcript_id', constraint_name => 'EXON_TRANSCRIPT_ID_FK' },
        transcript_id   => { is => 'NUMBER', len => 11 },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
