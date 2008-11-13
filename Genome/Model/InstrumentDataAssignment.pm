package Genome::Model::InstrumentDataAssignment;

use strict;
use warnings;

use Genome;
class Genome::Model::InstrumentDataAssignment {
    type_name => 'model instrument data assgnmnt',
    table_name => 'MODEL_INSTRUMENT_DATA_ASSGNMNT',
    id_by => [
        model_id           => { is => 'NUMBER', len => 10 },
        instrument_data_id => { is => 'VARCHAR2', len => 1000 },
    ],
    has => [
        first_build_id => { is => 'NUMBER', len => 10, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

#$HeadURL$
#$Id$
