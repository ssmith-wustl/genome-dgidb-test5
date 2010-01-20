package EGAP::RNAGene;

use strict;
use warnings;

use EGAP;


class EGAP::RNAGene {
    table_name => 'RNA_GENE',
    id_by => [ gene_id => { is => 'Number', len => 9 } ],
    has   => [
              gene_name => { is => 'Text', len => 60 },
              start     => { is => 'Number', len => 10, column_name => 'seq_start' },
              end       => { is => 'Number', len => 10, column_name => 'seq_end'   },
              strand    => { is => 'Number', len => 1, },
              source    => { is => 'Text', len => 25 },
              sequence  => { is => 'EGAP::Sequence', id_by => 'sequence_id' },
             ],
    data_source => 'EGAP::DataSource::EGAPSchema', 
};

1;
