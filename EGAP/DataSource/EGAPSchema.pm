use strict;
use warnings;

package EGAP::DataSource::EGAPSchema;

use EGAP;


class EGAP::DataSource::EGAPSchema {
    is        => ['UR::DataSource::Oracle'],
    type_name => 'egap datasource egapschema',
};

sub server {
    'dwdev';
}

sub login {
    'egapuser';
}

sub auth {
    'eg_dev';
}

sub owner {
    'EGAP';
}

1;
