package EGAP::SequenceSet;

use strict;
use warnings;

use EGAP;


class EGAP::SequenceSet {
    type_name => 'sequence set',
    table_name => 'SEQUENCE_SET',
    id_by => [
        sequence_set_id => { is => 'NUMBER', len => 7 },
    ],
    id_sequence_generator_name => 'sequence_set_id_seq',
    has => [
        data_version      => { is => 'VARCHAR2', len => 10 },
        organism          => { is => 'EGAP::Organism', id_by => 'organism_id', constraint_name => 'SS_ORG_FK' },
        organism_id       => { is => 'NUMBER', len => 6 },
        sequence_set_name => { is => 'VARCHAR2', len => 60 },
        software_version  => { is => 'VARCHAR2', len => 10 },
        sequences         => { is => 'EGAP::Sequence', reverse_as => 'sequence_set', is_many => 1 },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
