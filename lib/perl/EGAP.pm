package EGAP;

use warnings;
use strict;

use UR;

#use lib '/gsc/scripts/opt/bacterial-bioperl';

class EGAP {
    is          => ['UR::Namespace'],
    type_name   => 'egap',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
