package EGAP::Transcript;

use strict;
use warnings;

use EGAP;


class EGAP::Transcript {
    table_name => 'TRANSCRIPT',
    id_by => [ transcript_id => { is => 'Number', len => 12 } ],
    has   => [
              transcript_name => { is => 'Text', len => 60 },
              sequence_string => { is => 'BLOB'            },
              start           => { is => 'Number', len => 10, column_name => 'seq_start'},
              end             => { is => 'Number', len => 10, column_name => 'seq_end'},
              coding_start    => { is => 'Number', len => 5, },
              coding_end      => { is => 'Number', len => 5, },
              exons           => { is => 'EGAP::Exon', reverse_as => 'transcript', is_many => 1 }, 
              coding_gene     => { is => 'EGAP::CodingGene', id_by => 'gene_id' },
             ],
    data_source => 'EGAP::DataSource::EGAPSchema', 
};

1;
