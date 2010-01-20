package EGAP::Exon;

use strict;
use warnings;

use EGAP;


class EGAP::Exon {
    table_name => 'EXON',
    id_by => [ exon_id => { is => 'Number', len => 12 } ],
    has   => [
              sequence_string => { is => 'BLOB'            },
              start           => { is => 'Number', len => 10, column_name => 'seq_start'},
              end             => { is => 'Number', len => 10, column_name => 'seq_end'},
              transcript      => { is => 'EGAP::Transcript', id_by => 'transcript_id' },
             ],
    data_source => 'EGAP::DataSource::EGAPSchema', 
};

1;
