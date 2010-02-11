package EGAP::Sequence;

use strict;
use warnings;

use EGAP;


class EGAP::Sequence {
    type_name => 'dna sequence',
    table_name => 'DNA_SEQUENCE',
    id_sequence_generator_name => 'sequence_id_seq',
    id_by => [
        sequence_id => { is => 'NUMBER', len => 9 },
    ],
    has => [
        sequence_name   => { is => 'VARCHAR2', len => 50 },
        sequence_set_id => { is => 'NUMBER', len => 7 },
        sequence_string => { is => 'BLOB', len => 2147483647 },
        sequence_set    => { is => 'EGAP::SequenceSet', id_by => 'sequence_set_id', constraint_name => 'DS_SS_FK' },
    ],
    has_optional => [
         coding_genes    => { is => 'EGAP::CodingGene', reverse_as => 'sequence', is_many => 1 }, 
         trna_genes      => { is => 'EGAP::tRNAGene',   reverse_as => 'sequence', is_many => 1 }, 
         rna_genes       => { is => 'EGAP::RNAGene',    reverse_as => 'sequence', is_many => 1 }, 
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
