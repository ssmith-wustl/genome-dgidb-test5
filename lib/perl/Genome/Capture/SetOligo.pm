package Genome::Capture::SetOligo;

use strict;
use warnings;

use Genome;

class Genome::Capture::SetOligo {
    table_name => q|
        (select
            setup_capture_set_id set_id,
            atc_id oligo_id
        from capture_set@oltp
        ) set_oligo
    |,
    id_by => [
        set => {
            is => 'Genome::Capture::Set',
            id_by => 'set_id',
        },
        oligo => {
            is => 'Genome::Capture::Oligo',
            id_by => 'oligo_id',
        },
    ],
    has => {
        set_name => {
            via => 'set',
            to => 'name',
        },
    },
    doc => '',
    data_source => 'Genome::DataSource::GMSchema',
};
