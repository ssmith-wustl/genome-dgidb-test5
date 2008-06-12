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


sub _get_sequence_name_for_table_and_column {
    my ($self, $table_name, $column_name) = @_;
    if ($table_name =~ /PROCESSING_PROFILE/) {
        return 'PROCESSING_PROFILE_SEQ';
    }
    elsif ($column_name eq 'ID') {
        return $table_name . '_SEQ';
    }
    else {
        $self->SUPER::_get_sequence_name_for_table_and_column($table_name, $column_name);
    }
}

1;

