
use strict;
use warnings;

package Genome::DataSource::Main;

use UR;

UR::Object::Class->define(
    class_name => 'Genome::DataSource::Main',
    is => ['UR::DataSource::SQLite'],
    english_name => 'genome datasource main',
);

1;
