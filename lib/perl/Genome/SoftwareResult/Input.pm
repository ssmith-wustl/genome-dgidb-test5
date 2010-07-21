package Genome::SoftwareResult::Input;

use strict;
use warnings;

use Genome;
class Genome::SoftwareResult::Input {
    type_name => 'software result input',
    table_name => 'SOFTWARE_RESULT_INPUT',
    id_by => [
        input_name         => { is => 'VARCHAR2', len => 100 },
        software_result_id => { is => 'NUMBER', len => 20 },
    ],
    has => [
        input_value                     => { is => 'VARCHAR2', len => 1000 },
        software_result                 => { is => 'Genome::SoftwareResult', id_by => 'software_result_id', constraint_name => 'SRI_SR_FK' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
