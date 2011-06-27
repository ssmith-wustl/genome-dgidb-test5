package Genome::Model::Build::Command::Stop;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Stop {
    is => 'Genome::Model::Build::Command::Base',
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
    for my $build (@builds) {
        $self->total_command_count($self->total_command_count + 1);
        my $transaction = UR::Context::Transaction->begin();
        my $successful = eval {$build->stop};
        if ($successful and $transaction->commit) {
            $self->status_message("Successfully stopped build (" . $build->__display_name__ . ").");
        }
        else {
            push @errors, "Failed to stop build (" . $build->__display_name__ . "): $@.";
            $transaction->rollback();
        }
    }

    $self->display_command_summary_report();

    return !scalar(keys %{$self->command_errors});
}

1;

#$HeadURL$
#$Id$
