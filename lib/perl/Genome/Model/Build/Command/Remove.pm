package Genome::Model::Build::Command::Remove;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Remove {
    is => 'Genome::Model::Build::Command::Base',
    has => [
        builds => {
            is                  => 'Genome::Model::Build',
            is_many             => 1,
            shell_args_position => 1,
            doc => 'Build(s) to use. Resolved from command line via text string.',
            require_user_verify => 1,
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

# TODO This needs to be cleaned up
sub execute {
    my $self = shift;

    my @builds = $self->builds;
    my $build_count = scalar(@builds);
    for my $build (@builds) {
        $self->total_command_count($self->total_command_count + 1);
        my $transaction = UR::Context::Transaction->begin();
        my $display_name = $build->__display_name__;
        my $remove_build = Genome::Command::Remove->create(items => [$build], _deletion_params => [keep_build_directory => $self->keep_build_directory]);
        my $successful = eval {
            my @__errors__ = $build->__errors__;
            if (@__errors__) {
                die "build or instrument data has __errors__, cannot remove: " . join('; ', @__errors__);
            }
            $remove_build->execute;
        };
        if ($successful and $transaction->commit) {
            $self->status_message("Successfully removed build (" . $display_name . ").");
        }
        else {
            $self->append_error($display_name, "Failed to remove build: $@.");
            $transaction->rollback();
        }
    }

    $self->display_command_summary_report();

    return !scalar(keys %{$self->command_errors});
}

1;
