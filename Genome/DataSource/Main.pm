
use strict;
use warnings;

package Genome::DataSource::Main;

use UR;

UR::Object::Class->define(
    class_name => 'Genome::DataSource::Main',
    is => ['UR::DataSource::MySQL'],
    english_name => 'genome datasource main',
);

    
# This becomes the third part of the colon-separated data_source
# string passed to DBI->connect()
sub server {
    'dbname=genome_model_temp;host=mysql2';
}

sub db_name {
   'genome_model_temp';
}

        
# This becomes the schema argument to most of the data dictionary methods
# of DBI like table_info, column_info, etc.
sub owner {
    undef;
}
        
# This becomes the username argument to DBI->connect
sub login {
    'gm_user';
}
        
# This becomes the password argument to DBI->connect
sub auth {
    'gm';
}
        
1;
