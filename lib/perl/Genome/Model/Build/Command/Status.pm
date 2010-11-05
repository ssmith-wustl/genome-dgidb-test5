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
            require_user_verify => 0,
            doc => 'Build(s) to check status. Resolved from command line via text string.',
        },
        models => {
            is => 'Genome::Model',
            is_many => 1,
            doc => 'Model(s) to check latest build status. Resolved from command line via text string.',
            require_user_verify => 0,
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
        my @builds = sort {$a->model_name cmp $b->model_name} $self->builds;
        my $model_name;
        for my $build (@builds) {
            if ($model_name ne $build->model_name) {
                $model_name = $build->model_name;
                $self->status_message("Model: ".$model_name);
            }
            my $build_status = $build->status;
            $status{$build_status}++;
            $self->status_message("\t".$build->id."\t$build_status");
        }
    }
    elsif ($self->models) {
        for my $model ($self->models) {
            $self->status_message("Model: ".$model->name);
            my $build_id = $model->latest_build->id;
            my $build_status;
            if ($build_id) {
                my $build = Genome::Model::Build->get($build_id);
                $build_status = $build->status;
            }
            else {
                $build_status = "Buildless";
            }
            $build_id ||= "N/A";
            $status{$build_status}++;
            $self->status_message("\t".$build_id."\t$build_status");
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
