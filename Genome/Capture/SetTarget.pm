package Genome::Capture::SetTarget;

use strict;
use warnings;

use Genome;

class Genome::Capture::SetTarget {
    table_name => q|
        (select
            setup_capture_set_id capture_set_id,
            atc_id capture_target_id
        from capture_set@oltp
        ) capture_set_target
    |,
    id_by => [
        capture_set => {
            is => 'Genome::Capture::Set',
            id_by => 'capture_set_id',
        },
        capture_target => {
            is => 'Genome::Capture::Target',
            id_by => 'capture_target_id',
        },
    ],
    has => {
        capture_set_name => {
            via => 'capture_set',
            to => 'name',
        },
    },
    doc => '',
    data_source => 'Genome::DataSource::GMSchema',
};
