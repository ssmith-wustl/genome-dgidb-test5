package Genome::Model::Build::Command::Remove;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Remove {
    is => 'Genome::Model::Build::Command::Base',
    doc => 'delete a build and all of its data from the system'
};

#< Command >#
sub sub_command_sort_position { 7 }

sub help_brief {
    return 'Remove a build and all of its data';
}

sub help_detail {
    "This command will remove the build and all events that make up the build";
}

#< Execute >#
sub execute {
    my $self = shift;

    # Get build
    my $build = $self->_resolve_build
        or return;
    
    # Delete - also abandons
    unless ( $build->delete ) {
        $self->error_message('Failed to remove build ('.$build->id.')');
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
