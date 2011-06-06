package Genome::Model::Build::Command::AbandonAndQueue;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::AbandonAndQueue {
    is => 'Genome::Model::Build::Command::Base',
};

sub sub_command_sort_position { 6 }

sub help_brief {
    return "Abandon a build and queue the model for another build";
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
        my $successful = eval { $build->abandon; };
        if ($successful and $transaction->commit) {
            $build->model->build_requested(1);
            $self->status_message("Abandoned build (" . $build->__display_name__ . ") and queued model.");
        }
        else {
            push @errors, "Failed to abandon build (" . $build->__display_name__ . "): $@.";
            $transaction->rollback;
        }
    }

    $self->display_summary_report(scalar(@builds), @errors);

    return not @errors;
}

1;

