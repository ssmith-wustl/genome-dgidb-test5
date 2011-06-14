package Genome::SoftwareResult::Param;

use strict;
use warnings;

use Genome;
class Genome::SoftwareResult::Param {
    type_name => 'software result param',
    table_name => 'SOFTWARE_RESULT_PARAM',
    id_by => [
        param_name         => { is => 'VARCHAR2', len => 100 },
        software_result_id => { is => 'UR::Value::Number', len => 20 },
    ],
    has => [
        param_value                     => { is => 'VARCHAR2', len => 1000 },
        software_result                 => { is => 'Genome::SoftwareResult', id_by => 'software_result_id', constraint_name => 'SRP_SR_FK' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
