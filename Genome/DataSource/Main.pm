
use strict;
use warnings;

package Genome::DataSource::Main;

use UR;

UR::Object::Class->define(
    class_name => 'Genome::DataSource::Main',
    is => ['UR::DataSource::SQLite'],
    english_name => 'genome datasource main',
);

sub server {
	"/gscmnt/sata114/info/medseq/sample_data/Main.sqlite3";
}

1;
