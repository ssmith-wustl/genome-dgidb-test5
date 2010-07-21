package EGAP::DataSource::EGAPSchema;

use strict;
use warnings;

use EGAP;

class EGAP::DataSource::EGAPSchema {
    is => [ 'UR::DataSource::Oracle', 'UR::Singleton' ],
};

sub server { 'DWDEV' }
sub login { 'egapuser' }
sub auth { 'eg_dev' }
sub owner { 'EGAP' }

1;
