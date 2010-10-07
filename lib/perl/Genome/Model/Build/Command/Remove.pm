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

sub _limit_results_for_builds {
    my ($self, @builds) = @_;

    # Run Genome::Model::Build::Command::Base's _limit_results_for_builds
    @builds = $self->SUPER::_limit_results_for_builds(@builds);

    my @error_builds;
    my @error_free_builds;
    for my $build (@builds) {
        # Builds containing expunged data cannot be changed since any changes that try to be committed
        # will result in problems when the __errors__ method determines that the instrument data 
        # assignments point to instrument data that's been blown away. If problems are found, inform 
        # the user and skip the build
        my @errors = $build->__errors__;
        push @errors, map { $_->__errors__ } $build->instrument_data_assignments;

        if (@errors) {
            push @error_builds, $build;
        }
        else {
            push @error_free_builds, $build;
        }
    }
    if (@error_builds) {
        $self->warning_message("Errors found on some builds and/or their instrument data assignments,\n".
            "cannot remove this build!\nErrors like \"There is no instrument data...\" mean the build ".
            "deals with expunged data. Contact apipe!\n".
            "The builds are:\n".
            join("\n", map { $_->__display_name__ } @error_builds));
    }
    @builds = @error_free_builds;

    return @builds;
}
sub execute {
    my $self = shift;

    my @builds = $self->builds;
    my $build_count = scalar(@builds);
    my $failed_count = 0;
    my @errors;
    for my $build (@builds) {
        my $display_name = $build->__display_name__;
        my $remove_build = Genome::Command::Remove->create(items => [$build], _deletion_params => [keep_build_directory => $self->keep_build_directory]);
        my $rv = eval {$remove_build->execute};
        if ($rv) {
            $self->status_message("Successfully removed build (" . $display_name . ").");
        }
        else {
            $self->error_message($@);
            $failed_count++;
            push @errors, "Failed to remove build (" . $display_name . ").";
        }
    }
    for my $error (@errors) {
        $self->status_message($error);
    }
    if ($build_count > 1) {
        $self->status_message("Stats:");
        $self->status_message(" Removed: " . ($build_count - $failed_count));
        $self->status_message("  Errors: " . $failed_count);
        $self->status_message("   Total: " . $build_count);
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

1;
