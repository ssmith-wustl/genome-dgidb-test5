package EGAP::SequenceSet;

use strict;
use warnings;

use EGAP;


class EGAP::SequenceSet {
    table_name => 'SEQUENCE_SET',
    id_by => [ sequence_set_id => { is => 'Number', len => 7 } ],
    id_sequence_generator_name => 'sequence_set_id_seq',
    has   => [
              sequence_set_name => { is => 'Text',   len => 60 },
              organism_id       => { is => 'Number', len => 6  },
              software_version  => { is => 'Number', len => 10 },
              data_version      => { is => 'Number', len => 10 },
              sequences         => { is => 'EGAP::Sequence', reverse_as => 'sequence_set', is_many => 1 },
             ],
    data_source => 'EGAP::DataSource::EGAPSchema', 
};

1;
