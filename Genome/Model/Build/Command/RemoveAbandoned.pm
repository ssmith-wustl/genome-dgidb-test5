package Genome::Model::Build::Command::RemoveAbandoned;

use strict;
use warnings;
use Genome;
use Carp;

class Genome::Model::Build::Command::RemoveAbandoned {
    is => 'Genome::Model::Build::Command',
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
        # will result in problems when the __errors__ method determines that the instrument data assignments
        # point to instrument data that's been blown away. If problems are found, inform the user and skip the build
        $self->status_message("Checking the build and its instrument data assignments for problems...");
        my @errors = $build->__errors__;
        push @errors, map { $_->__errors__ } $build->instrument_data_assignments;

        if (@errors) {
            push @failed_builds, $build_id;
            $self->warning_message("Errors found on build and/or instrument data assignments, cannot remove this build!\n" .
                "Errors like \"There is no instrument data...\" mean the build deals with expunged data. Contact apipe!\n" .
                join("\n", map { $_->desc } @errors));
            next;
        }

        # Using a transaction for committing/rolling back is necessary to prevent problems when rolling back the
        # UR context... In that case, this command object (which has been created and uncommitted) gets removed and any
        # further access to $self results in a "Attempt to use a reference to an object which has been deleted" error message
        my $trans_rv;
        eval { 
            my $trans = UR::Context::Transaction->begin;
            $trans_rv = $build->delete(keep_build_directory => $self->keep_build_directory);
            $trans->commit if $trans_rv;
        };

        # If a commit either doesn't happen or dies in the above eval, a rollback is automagically performed. Also, trans_rv
        # won't get a value back, so it can be checked to determine if there were any problems
        unless (defined $trans_rv and $trans_rv) {
            push @failed_builds, $build_id;
            $self->error_message("Problem removing build! Rolling back changes and skipping this build!");
            next;
        }

        # Finally, perform a UR::Context->commit. The transaction's commit above does not call the __errors__ method on changed
        # objects, so there a chance this commit will fail (though I've tried to cover my bases as best as I can). If the commit
        # fails, a rollback of the UR::Context is NOT possible, since that would delete this command object. So an error summary
        # is printed and the command blows up... :(
        my $commit_rv = eval { UR::Context->commit };
        unless (defined $commit_rv and $commit_rv) {
            push @failed_builds, $build_id;
            $self->error_message("Cannot perform a UR::Context->commit and cannot rollback changes! Printing summary and bailing out!");
            $self->print_error_summary(\@failed_builds);
            croak;
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
        $self->error_message("\n\n\nCould not remove " . scalar @$failed_builds . " builds:\n" . join("\n", @$failed_builds));
    }
    else {
        $self->status_message("\n\n\nAll builds successfully removed!");
    }
    return 1;
}

1;

