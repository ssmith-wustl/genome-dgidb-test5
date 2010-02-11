package EGAP::RNAGene;

use strict;
use warnings;

use EGAP;


class EGAP::RNAGene {
    type_name => 'rna gene',
    table_name => 'RNA_GENE',
    id_sequence_generator_name => 'gene_id_seq',
    id_by => [
        gene_id => { is => 'NUMBER', len => 9 },
    ],
    has => [
        acc          => { is => 'VARCHAR2', len => 20 },
        description  => { is => 'VARCHAR2', len => 30 },
        sequence     => { is => 'EGAP::Sequence', id_by => 'sequence_id', constraint_name => 'TRNA_GENE_SEQUENCE_ID_FK' },
        gene_name    => { is => 'VARCHAR2', len => 60 },
        product      => { is => 'VARCHAR2', len => 100, is_optional => 1 },
        score        => { is => 'NUMBER', len => 5, is_optional => 1 },
        end          => { is => 'NUMBER', len => 10, column_name => 'SEQ_END' },
        start        => { is => 'NUMBER', len => 10, column_name => 'SEQ_START' },
        sequence_id  => { is => 'NUMBER', len => 9 },
        source       => { is => 'VARCHAR2', len => 25 },
        strand       => { is => 'NUMBER', len => 1 },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
