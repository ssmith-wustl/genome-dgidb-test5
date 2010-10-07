package Genome::Model::Build::Command::Stop;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Stop {
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
};

sub sub_command_sort_position { 5 }

sub help_brief {
    "Stop a build";
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;

    my @builds = $self->builds;
    my $build_count = scalar(@builds);
    my $failed_count = 0;
    my @errors;
    for my $build (@builds) {
        my $rv = eval {$build->stop};
        if ($rv) {
            $self->status_message("Successfully stopped build (" . $build->__display_name__ . ").");
        }
        else {
            $self->error_message($@);
            $failed_count++;
            push @errors, "Failed to stop build (" . $build->__display_name__ . ").";
        }
    }
    for my $error (@errors) {
        $self->status_message($error);
    }
    if ($build_count > 1) {
        $self->status_message("Stats:");
        $self->status_message(" Stopped: " . ($build_count - $failed_count));
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

#$HeadURL$
#$Id$
