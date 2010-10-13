package Genome::Model::Build::Command::Abandon;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Abandon {
    is => 'Genome::Model::Build::Command::Base',
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

    my @builds = $self->builds;
    my $build_count = scalar(@builds);
    my $failed_count = 0;
    my @errors;
    for my $build (@builds) {
        my $rv = eval {$build->abandon};
        if ($rv) {
            $self->status_message("Successfully abandoned build (" . $build->__display_name__ . ").");
        }
        else {
            $self->error_message($@);
            $failed_count++;
            push @errors, "Failed to abandon build (" . $build->__display_name__ . ").";
        }
    }
    for my $error (@errors) {
        $self->status_message($error);
    }
    if ($build_count > 1) {
        $self->status_message("Stats:");
        $self->status_message(" Abandonded: " . ($build_count - $failed_count));
        $self->status_message("     Errors: " . $failed_count);
        $self->status_message("      Total: " . $build_count);
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
