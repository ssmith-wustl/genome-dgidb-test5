package Genome::Model::Build::Command::Remove;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Remove {
    is => 'Genome::Model::Build::Command::Base',
    has_optional => [
        keep_build_directory => {
            is => 'Boolean',
            default_value => 0,
            doc => 'A boolean flag to allow the retention of the model directory after the model is purged from the database.(default_value=0)',
        },
    ],
};

sub sub_command_sort_position { 7 }

sub help_brief {
    "Remove a build.";
}

sub help_detail {
    "This command will remove a build from the system.  The rest of the model remains the same, as does independent data like alignments.";
}

sub execute {
    my $self = shift;

    # Get build
    my $build = $self->_resolve_build
        or return;

    # Remove
    my $remove_build = Genome::Command::Remove->create(items => [$build], _deletion_params => [keep_build_directory => $self->keep_build_directory]);
    unless ($remove_build->execute()) {
        die $self->error_message("Failed to remove build.");
    }
    return 1;
}

1;
