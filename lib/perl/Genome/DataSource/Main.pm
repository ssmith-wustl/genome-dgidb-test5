package Genome::DataSource::Main;

use strict;
use warnings;
use Genome;

class Genome::DataSource::Main {
    is => 'UR::DataSource::Pg',
    has_constant => [
        server => { default_value => 'dbname=genome;host=localhost' },
        login => { default_value => 'genome' },
        auth => { default_value => 'gsclab1' },
        owner => { default_value => 'public' },
    ],
};

1;

