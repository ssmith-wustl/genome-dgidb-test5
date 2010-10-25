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
    my @errors;
    for my $build (@builds) {
        my $transaction = UR::Context::Transaction->begin();
        my $successful = eval { $build->abandon };
        if ($successful) {
            $self->status_message("Successfully abandoned build (" . $build->__display_name__ . ").");
            $transaction->commit();
        }
        else {
            push @errors, "Failed to abandon build (" . $build->__display_name__ . "): $@.";
            $transaction->rollback;
        }
    }

    $self->display_summary_report(scalar(@builds), @errors);

    return !scalar(@errors);
}

1;

#$HeadURL$
#$Id$
