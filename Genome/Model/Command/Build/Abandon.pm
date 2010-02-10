package Genome::Model::Command::Build::Abandon;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Abandon {
    is => 'Genome::Model::Command::Build::Base',
};

sub sub_command_sort_position { 5 }

sub help_brief {
    return "Abandon a build and it's events";
}

sub help_detail {
    return help_brief();
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

    printf("Successfully abandoned build (%s).\n", $build->id);

    return 1;
}

1;

#$HeadURL$
#$Id$
