package Genome::InstrumentData::Attribute;

use strict;
use warnings;
use Genome;

class Genome::InstrumentData::Attribute {
    table_name => 'INSTRUMENT_DATA_ATTRIBUTE',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Represents a particular attribute of an instrument data object'
    id_by => [
        instrument_data_id => {
            is => 'Text',
        },
        attribute_label => {
            is => 'Text',
        },
        attribute_value => {
            is => 'Text',
        },
    ],
    has => [
        # TODO Should be in id_by, but currently can't have a property in id_by that
        # also has a default value
        nomenclature => {
            is => 'Text',
            default => 'WUGC',
        },
        instrument_data => {
            is => 'Genome::InstrumentData',
            id_by => 'instrument_data_id',
        },
    ],
};

1;

