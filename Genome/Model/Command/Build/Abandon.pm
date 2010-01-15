package Genome::Model::Command::Build::Abandon;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Abandon {
    is => 'Genome::Model::Command::Build::Base',
};

sub sub_command_sort_position { 5 }

sub help_detail {
    "Abandon a build and it's events";
}

sub execute {
    my $self = shift;

    # Get build
    my $build = $self->_resolve_build
        or return;

    # Abandon
    unless ( $build->abandon ) {
        $self->error_message("Failed to abandon build. See above errors.");
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
