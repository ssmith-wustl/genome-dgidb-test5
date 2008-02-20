package Genome::DataSource::Diffs;

# The datasource for metadata describing the tables, columns and foreign
# keys in the target datasource

use strict;
use warnings;

use UR;

UR::Object::Type->define(
    class_name => 'Genome::DataSource::Diffs',
    is => ['UR::DataSource::SQLite'],
);


1;
