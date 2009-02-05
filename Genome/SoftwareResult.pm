package Genome::SoftwareResult;

use strict;
use warnings;

use Genome;

class Genome::SoftwareResult {
    type_name => 'software result',
    table_name => 'SOFTWARE_RESULT',
    has => [
        inputs_id    => { is => 'VARCHAR2', len => 4000, is_optional => 1 },
        params_id    => { is => 'VARCHAR2', len => 4000, is_optional => 1 },
        id           => { is => 'NUMBER', len => 10 },
        class_name   => { is => 'VARCHAR2', len => 255 },
        version      => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        outputs_path => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
