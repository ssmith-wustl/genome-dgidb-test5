package Genome::ProcessingProfile;

use strict;
use warnings;

use Genome;
class Genome::ProcessingProfile {
    type_name => 'processing profile',
    table_name => 'PROCESSING_PROFILE',
    id_by => [
        id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        name      => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        type_name => { is => 'VARCHAR2', len => 255, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
