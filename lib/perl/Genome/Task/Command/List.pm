package Genome::Task::Command::List;

use warnings;
use strict;
use Genome;
use JSON::XS;
use File::Path;

class Genome::Task::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Task' 
        },
        show => { default_value => 'id,user_id,status,time_submitted', doc => 'properties of the model-group to list (comma-delimited)', is_optional => 1 },
    ],
    doc => 'list model-groups',
};

sub execute {
    my $self = shift;

    my $ds = $UR::Context::current->resolve_data_sources_for_class_meta_and_rule(Genome::Task->__meta__);
    my $dbh = $ds->get_default_dbh;
    my $orig_long_read_len = $dbh->{LongReadLen};
    $dbh->{LongReadLen} = 30_000_000;
    my $rv = $self->SUPER::_execute_body(@_);

    $dbh->{LongReadLen} = $orig_long_read_len;
    return $rv;
}
