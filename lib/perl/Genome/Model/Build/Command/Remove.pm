package Genome::Model::Build::Command::Remove;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Remove {
    is => 'Genome::Command::Base',
    has => [
        builds => {
            is => 'Genome::Model::Build',
            require_user_verify => 1,
            is_many => 1,
            shell_args_position => 1,
            doc => 'Build(s) to use. Resolved from command line via text string.',
        },
    ],
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
