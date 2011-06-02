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
    my @errors;
    for my $build (@builds) {
        my $transaction = UR::Context::Transaction->begin();
        my $successful = eval {$build->stop};
        if ($successful) {
            if ($transaction->commit) {
                $self->status_message("Successfully stopped build (" . $build->__display_name__ . ").");
            }
        }
        else {
            push @errors, "Failed to stop build (" . $build->__display_name__ . "): $@.";
            $transaction->rollback();
        }
    }

    $self->display_summary_report(scalar(@builds), @errors);

    return !scalar(@errors);
}

1;

#$HeadURL$
#$Id$
