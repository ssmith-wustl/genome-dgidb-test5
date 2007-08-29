
use strict;
use warnings;

package Genome::DataSource::Main;

use UR;

UR::Object::Class->define(
    class_name => 'Genome::DataSource::Main',
    is => ['UR::DataSource::SQLite'],
    english_name => 'genome datasource main',
);

    
sub _database_file_path {
    return '/gscuser/boberkfe/genome_model.sqlite3';
}


1;
