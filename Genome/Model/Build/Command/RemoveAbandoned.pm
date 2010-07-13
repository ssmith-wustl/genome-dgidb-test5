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
        # Using a transaction for committing/rolling back is necessary to prevent problems when rolling back the
        # UR context... In that case, this command object (which has been created and uncommitted) gets removed and any
        # further access to $self results in a "Attempt to use a reference to an object which has been deleted" error message
        my $trans = UR::Context::Transaction->begin;
        
        my $trans_rv;
        eval { 
            my $trans = UR::Context::Transaction->begin;
            $trans_rv = $build->delete(keep_build_directory => $self->keep_build_directory);
            $trans->commit if $trans_rv;
        };

        # If a commit either doesn't happen or dies in the above eval, a rollback is automagically performed. Also, trans_rv
        # won't get a value back, so it can be checked to determine if there were any problems
        unless (defined $trans_rv and $trans_rv) {
            $self->error_message("Problem removing build! Rolling back changes and skipping this build!");
            push @failed_builds, $build->build_id;
            next;
        }

        # The __errors__ method on changed objects is not called when a transaction is committed. Committing to the UR context
        # performs this check (which is what fails if any of the instrument data assignments messes with expunged data)
        my $commit_rv = eval { UR::Context->commit };
        unless (defined $commit_rv and $commit_rv) {
            $self->error_message("Problem committing build removal! Rolling back and skipping this build!");
            $trans->rollback;
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

