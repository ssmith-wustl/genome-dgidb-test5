package EGAP::Transcript;

use strict;
use warnings;

use EGAP;


class EGAP::Transcript {
    type_name => 'transcript',
    table_name => 'TRANSCRIPT',
    id_sequence_generator_name => 'transcript_id_seq',
    id_by => [
        transcript_id => { is => 'NUMBER', len => 12 },
    ],
    has => [
        coding_end      => { is => 'NUMBER', len => 5 },
        coding_start    => { is => 'NUMBER', len => 5 },
        gene_id         => { is => 'NUMBER', len => 11 },
        end             => { is => 'NUMBER', len => 10, column_name => 'SEQ_END' },
        start           => { is => 'NUMBER', len => 10, column_name => 'SEQ_START' },
        sequence_string => { is => 'BLOB', len => 2147483647 },
        transcript_name => { is => 'VARCHAR2', len => 60 },
        exons           => { is => 'EGAP::Exon', reverse_as => 'transcript', is_many => 1 }, 
        coding_gene     => { is => 'EGAP::CodingGene', id_by => 'gene_id' },
    ],
    unique_constraints => [
        { properties => [qw/gene_id transcript_name/], sql => 'TRANS_GENE_ID_NAME_U' },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
