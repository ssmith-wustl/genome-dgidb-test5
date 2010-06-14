package Genome::Model::Build::Command::RemoveAbandoned;

use strict;
use warnings;
use Genome;
use Carp;

class Genome::Model::Build::Command::RemoveAbandoned {
    is => 'Genome::Model::Build::Command',
    doc => 'Removes all abandoned build owned by the user executing this command',
    has => [
        keep_build_directory => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'If set, builds directories for all removed builds will be deleted',
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
        my $return_value = $build->delete(keep_build_directory => $self->keep_build_directory);
        unless ($return_value) {
            $self->error_message("Problem removing build " . $build->build_id . ", skipping!");
            UR::Context->rollback;
            push @failed_builds, $build->build_id;
            next;
        }
        
        my $commit_rv = UR::Context->commit;
        unless ($commit_rv) {
            $self->error_message("Could not commit deletion of build " . $build->build_id . ", rolling back and skipping!");
            UR::Context->rollback;
            push @failed_builds, $build->build_id;
            next;
        }

        $num++;
        $self->status_message("\n\n$num of $total builds successfully removed!\n\n\n");
    }

    if (@failed_builds) {
        $self->error_message("Could not remove " . scalar @failed_builds . " builds:\n " . join("\n", @failed_builds));
    }
    else {
        $self->status_message("All builds successfully removed!");
    }
    return 1;
}

1;

