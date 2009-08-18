package Genome::SoftwareResultUser;

use strict;
use warnings;

use Genome;
class Genome::SoftwareResultUser {
    type_name => 'software result user',
    table_name => 'SOFTWARE_RESULT_USER',
    id_by => [
        id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        software_result_id => { is => 'NUMBER', len => 20 },
        user_id            => { is => 'VARCHAR2', len => 256 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Usage pattern: rows will be added to this table while a given result is in use, and removed when the user is done with the data. Builds used in publications may stay "used" indefinitely, but most data will be temporary.',
};

1;
