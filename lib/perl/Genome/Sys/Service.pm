package Genome::Sys::Service;
use strict;
use warnings;
use Genome;

class Genome::Sys::Service {
    table_name => 'service',
    doc         => 'a service used by the genome system',
    data_source => 'Genome::DataSource::Service',

    id_generator => '-uuid',
    id_by => [
        id => { is => 'Text' },
    ],

    has_optional => [
        name => { is => 'Text' },
        host => { is => 'Text' },
        restart_command => { is => 'Text' },
        stop_command => { is => 'Text' },
        log_path => { is => 'Text' },
        status => { is => 'Text' },
        pid_status => { is => 'Text' },
        pid_name => { is => 'Text' },
        url => { is => 'Text' },
    ],
};

sub __display_name__ {
    my $self = shift;
    return $self->name . ' (' . $self->host . ')';
}
