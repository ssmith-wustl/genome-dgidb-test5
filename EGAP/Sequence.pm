package EGAP::Sequence;

use strict;
use warnings;

use EGAP;


class EGAP::Sequence {
    table_name => 'DNA_SEQUENCE',
    id_by => [ sequence_id => { is => 'Number', len => 9 } ],
    id_sequence_generator_name => 'sequence_id_seq',
    has   => [
              sequence_name   => { is => 'Text', len => 50 },
              sequence_string => { is => 'BLOB'            },
              sequence_set    => { is => 'EGAP::SequenceSet', id_by => 'sequence_set_id' },
             ],
    has_optional => [
                     coding_genes    => { is => 'EGAP::CodingGene', reverse_as => 'sequence', is_many => 1 }, 
                     trna_genes      => { is => 'EGAP::tRNAGene',   reverse_as => 'sequence', is_many => 1 }, 
                     rna_genes       => { is => 'EGAP::RNAGene',    reverse_as => 'sequence', is_many => 1 }, 
                    ],
    data_source => 'EGAP::DataSource::EGAPSchema', 
};

1;
