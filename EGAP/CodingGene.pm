package EGAP::CodingGene;

use strict;
use warnings;

use EGAP;


class EGAP::CodingGene {
    table_name => 'CODING_GENE',
    id_by => [ gene_id => { is => 'Number', len => 11 } ],
    has   => [
              gene_name       => { is => 'Text', len => 60 },
              sequence_string => { is => 'BLOB'            },
              strand          => { is => 'Number', len => 1},
              score           => { is => 'Number', len => 5},
              source          => { is => 'Text', len => 25},
              start           => { is => 'Number', len => 10, column_name => 'seq_start'},
              end             => { is => 'Number', len => 10, column_name => 'seq_end'},
              sequence        => { is => 'EGAP::Sequence', id_by => 'sequence_id' },
              transcripts     => { is => 'EGAP::Transcript', reverse_as => 'coding_gene', is_many => 1}, 
             ],
    data_source => 'EGAP::DataSource::EGAPSchema', 
};

1;
