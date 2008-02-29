use strict;
use warnings;

package Genome::DataSource::GMSchema;

use Genome;

class Genome::DataSource::GMSchema {
    is => ['UR::DataSource::Oracle'],
    type_name => 'genome datasource gmschema',
};

sub server {
    "dwrac";
}

sub login {
    "mguser";}

sub auth {
    "mguser_prd";}

sub owner {
    "MG";}


1;
