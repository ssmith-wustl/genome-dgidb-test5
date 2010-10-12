package Genome::Model::Build::Command::StatusSummary;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::StatusSummary {
    is => 'Genome::Command::Base',
    doc => "check status of builds",
    has_optional => [
        builds => {
            is => 'Genome::Model::Build',
            is_many => 1,
            doc => 'Build(s) to check status. Resolved from command line via text string.',
        },
        models => {
            is => 'Genome::Model',
            is_many => 1,
            doc => 'Model(s) to check latest build status. Resolved from command line via text string.',
            shell_args_position => 1,
        },
    ],
};

sub execute {
    my $self = shift;

    unless ($self->builds xor $self->models) {
        $self->error_message("Please specify whether you want a summary based on builds or models but not both.");
    }

    my %status;
    if ($self->builds) {
        for my $build ($self->builds) {
            $status{$build->status}++;
        }
    }
    elsif ($self->models) {
        for my $model ($self->models) {
            my $build_id = $model->latest_build;
            if ($build_id) {
                my $build = Genome::Model::Build->get($build_id);
                $status{$build->status}++;
            }
            else {
                $status{Other}++;
            }
        }
    }
    else {
        $self->error_message("Should not have reached this condtional!");
    }

    my $total;
    for my $key (sort keys %status) {
        $total += $status{$key};
    }

    for my $key (sort keys %status) {
        print "$key: $status{$key}\t";
    }
    print "Total: $total\n";

    return 1;
}

1;
