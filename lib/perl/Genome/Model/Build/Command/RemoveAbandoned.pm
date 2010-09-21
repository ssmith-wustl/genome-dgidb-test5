package Genome::Model::Build::Command::RemoveAbandoned;

use strict;
use warnings;
use Genome;
use Carp;

class Genome::Model::Build::Command::RemoveAbandoned {
    is => 'Command',
    doc => 'Removes all abandoned build owned by the user',
    has => [
        keep_build_directory => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'If set, builds directories for all removed builds will be kept',
        },
    ],
};

sub help_brief {
    return 'Remove all abandoned builds owned by the user';
}

sub help_detail {
    return <<EOS
This command will grab all builds owned by the user and remove them all
EOS
}

sub execute {
    my $self = shift;

    my $user = $ENV{USER};
    confess "Could not get user name from environment" unless defined $user;

    my @builds = Genome::Model::Build->get(
        status => 'Abandoned',
        run_by => $user,
    );

    unless (@builds) {
        $self->status_message("No builds owned by $user are abandoned, so no removal necessary!");
        return 1;
    }

    $self->status_message("User $user has " . scalar @builds . " abandoned builds.");
    $self->status_message(join("\n", map { $_->build_id } @builds));
    $self->status_message("Are you sure you want to remove these builds? (y/n) [n]");
    my $answer = <STDIN>;
    return 1 unless $answer =~ /^[yY]/;

    my $total = scalar @builds;
    my $num = 0;
    my @failed_builds;
    for my $build (@builds) {
        my $build_id = $build->build_id;

        $self->status_message("\n\n\nAttempting to remove build $build_id");

        # Builds containing expunged data cannot be changed since any changes that try to be committed
        # will result in problems when the __errors__ method determines that the instrument data 
        # assignments point to instrument data that's been blown away. If problems are found, inform 
        # the user and skip the build
        $self->status_message("Checking the build and its instrument data assignments for problems...");
        my @errors = $build->__errors__;
        push @errors, map { $_->__errors__ } $build->instrument_data_assignments;

        if (@errors) {
            push @failed_builds, $build_id;
            $self->warning_message("Errors found on build and/or instrument data assignments, cannot " . 
                "remove this build!\nErrors like \"There is no instrument data...\" mean the build " .
                "deals with expunged data. Contact apipe!\n" . join("\n", map { $_->desc } @errors));
            next;
        }

        # If there is a problem committing the build removal, there is no way to directly recover from 
        # it. As a workaround, run the existing build removal tool in an eval wrapped system call.
        $self->status_message("No problems found, attempting removal...");

        my $cmd = "genome model build remove ";
        $cmd .= "--keep-build-directory " if $self->keep_build_directory;
        $cmd .= "--ITEMS $build_id";
        my $rv = eval { system($cmd) };

        unless (defined $rv and $rv == 0) {
            push @failed_builds, $build_id;
            $self->warning_message("Could not remove build $build_id!");
            next;
        }

        $num++;
        $self->status_message("\n\n$num of $total builds successfully removed!");
    }

    $self->print_error_summary(\@failed_builds);
    return 1;
}

sub print_error_summary {
    my ($self, $failed_builds) = @_;
    
    if (@$failed_builds) {
        $self->status_message("Could not remove " . scalar @$failed_builds . 
            " builds:\n" . join("\n", @$failed_builds));
    }
    else {
        $self->status_message("All builds successfully removed!");
    }
    return 1;
}

1;

