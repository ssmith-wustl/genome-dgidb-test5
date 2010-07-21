package EGAP::CodingGene;

use strict;
use warnings;

use EGAP;


class EGAP::CodingGene {
    type_name => 'coding gene',
    table_name => 'CODING_GENE',
    id_sequence_generator_name => 'gene_id_seq',
    id_by => [
        gene_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        blastp_evidence => { is => 'NUMBER', len => 1 },
        sequence        => { is => 'EGAP::Sequence', id_by => 'sequence_id', constraint_name => 'CG_SEQUENCE_ID_FK' },
        fragment        => { is => 'NUMBER', len => 1 },
        gene_name       => { is => 'VARCHAR2', len => 60 },
        internal_stops  => { is => 'NUMBER', len => 1 },
        missing_start   => { is => 'NUMBER', len => 1 },
        missing_stop    => { is => 'NUMBER', len => 1 },
        pfam_evidence   => { is => 'NUMBER', len => 1 },
        score           => { is => 'NUMBER', len => 5, is_optional => 1 },
        end             => { is => 'NUMBER', len => 10, column_name => 'SEQ_END' },
        start           => { is => 'NUMBER', len => 10, column_name => 'SEQ_START' },
        sequence_id     => { is => 'NUMBER', len => 9 },
        sequence_string => { is => 'BLOB', len => 2147483647 },
        source          => { is => 'VARCHAR2', len => 25 },
        strand          => { is => 'NUMBER', len => 1 },
        wraparound      => { is => 'NUMBER', len => 1 },
        transcripts     => { is => 'EGAP::Transcript', reverse_as => 'coding_gene', is_many => 1},
    ],
    unique_constraints => [
        { properties => [qw/gene_name sequence_id/], sql => 'CG_SEQID_GNAME_U' },
        { properties => [qw/gene_id sequence_id/], sql => 'CG_CGID_SEQID' },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
