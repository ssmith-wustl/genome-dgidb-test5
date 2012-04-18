package Genome::Site::WUGC::Observers::Context;

use strict;
use warnings;

UR::Context->add_observer(
    aspect => 'precommit',
    callback => \&pause,
);

sub pause {
    my $self = shift;
    return 1 unless -e $ENV{GENOME_DB_PAUSE};

    print "Database updating has been paused, please wait until updating has been resumed...\n";

    my @data_sources = $self->all_objects_loaded('UR::DataSource::RDBMS');
    for my $ds (@data_sources) {
        $ds->disconnect_default_handle if $ds->has_default_handle;
    }

    while (1) {
        sleep sleep_length();
        last unless -e $ENV{GENOME_DB_PAUSE};
    }

    print "Database updating has been resumed, continuing commit!\n";
    return 1;
}

sub sleep_length {
    return 30;
}

1;

