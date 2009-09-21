package Genome::Capture::Set;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set {
    table_name => q|
        (select
            setup_name name,
            setup_id id,
            setup_status status,
            setup_description description
        from setup@oltp
        where setup_type = 'setup capture set'
        ) capture_set
    |,
    id_by => [
        id => { },
    ],
    has => {
        name => { },
        description => { },
        status => { },
    },
    has_many_optional => {
        capture_set_targets => {
            is => 'Genome::Capture::SetTarget',
            reverse_id_by => 'capture_set',
        }
    },
    doc         => '',
    data_source => 'Genome::DataSource::GMSchema',
};
