package Genome::MiscAttribute;

use strict;
use warnings;

use Genome;
class Genome::MiscAttribute {
    table_name => 'MISC_ATTRIBUTE',
    id_by => [
        entity_id         => { is => 'VARCHAR2', len => 1000 },
        entity_class_name => { is => 'VARCHAR2', len => 255, },
        property_name     => { is => 'VARCHAR2', len => 255 },
    ],
    has => [
        value             => { is => 'VARCHAR2', len => 4000, is_optional => 1 },
        #entity            => { is => 'UR::Object', id_by => 'entity_id' },
        entity            => { is => 'Genome::InstrumentData', id_by => 'entity_id' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

#$HeadURL$
#$Id$
