package EGAP::tRNAGene;

use strict;
use warnings;

use EGAP;


class EGAP::tRNAGene {
    type_name => 'trna gene',
    table_name => 'TRNA_GENE',
    id_sequence_generator_name => 'gene_id_seq',
    id_by => [
        gene_id => { is => 'NUMBER', len => 9 },
    ],
    has => [
        gene_name    => { is => 'VARCHAR2', len => 60 },
        start        => { is => 'NUMBER', len => 10, column_name => 'SEQ_START' },
        end          => { is => 'NUMBER', len => 10, column_name => 'SEQ_END' },
        strand       => { is => 'NUMBER', len => 1 },
        source       => { is => 'VARCHAR2', len => 25 },
        score        => { is => 'NUMBER', len => 5, is_optional => 1 },
        codon        => { is => 'VARCHAR2', len => 3 },
        aa           => { is => 'VARCHAR2', len => 9 },
        sequence     => { is => 'EGAP::Sequence', id_by => 'sequence_id', constraint_name => 'TG_SEQ_ID_FK' },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
