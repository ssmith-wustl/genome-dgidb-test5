package Genome::Model::Command::Services::Review::Models;

class Genome::Model::Command::Services::Review::Models {
    is => 'Genome::Command::Base',
    doc => 'Tool for the Cron Tzar to review builds, e.g. missing builds, failed builds, etc.',
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            shell_args_position => 1,
            require_user_verify => 0,
        },
        hide_statuses => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'Hide build details for statuses listed.',
        },
    ],
};

use strict;
use warnings;
use Genome;

sub execute {
    my $self = shift;

    my @models = $self->models;
    my @hide_statuses = $self->hide_statuses;

    for my $model (@models) {
        my $latest_build        = ($model        ? $model->latest_build  : undef);
        my $latest_build_status = ($latest_build ? $latest_build->status : '-');

        next if (grep { lc $_ eq lc $latest_build_status } @hide_statuses);

        my $fail_count   = ($model ? scalar $model->failed_builds     : undef);
        my $model_id     = ($model ? $model->id                       : '-');
        my $model_name   = ($model ? $model->name                     : '-');
        my $pp_name      = ($model ? $model->processing_profile->name : '-');

        my $latest_build_revision = (($latest_build && $latest_build->software_revision) ? $latest_build->software_revision : '-');

        $model_name =~ s/\.?$pp_name\.?/.../;
        
        $latest_build_revision =~ s/\/gsc\/scripts\/opt\/genome\/snapshots\/[\w\-]+\///;
        $latest_build_revision =~ s/\/lib\/perl\/?//;
        $latest_build_revision =~ s/:$//;

        my $action;
        if ($latest_build->status eq 'Scheduled' || $latest_build->status eq 'Running') {
            $action = 'none';
        }
        elsif ($latest_build && $latest_build->status eq 'Succeeded') {
            $action = 'cleanup';
        }
        elsif (should_review_model($model)) {
            $action = 'review';
        }
        else {
            $action = 'rebuild';
        }

        $self->print_message(join "\t", $model_id, $action, $latest_build_status, $latest_build_revision, $model_name, $pp_name, $fail_count);
    }

    return 1;
}


sub print_message {
    my $self = shift;
    my $msg = shift;
    print STDOUT $msg . "\n";
    return 1;
}


sub should_review_model {
    my $model = shift;

    # If the latest build succeeded then we're happy.
    return if latest_build_succeeded($model);

    my @builds = $model->builds;
    return if @builds <= 1;

    # If it has failed >3 times in a row then submit for review.
    return 1 if model_has_failed_three_times_in_a_row($model);

    # If it hasn't made progress since last time then submit for review.
    return 1 unless model_has_progressed($model);

    return;
}


sub latest_build_succeeded {
    my $model = shift;

    my $latest_build = $model->latest_build;
    return ($latest_build->status eq 'Succeeded');
}


sub model_has_failed_three_times_in_a_row {
    my $model = shift;

    my @builds = reverse $model->builds;
    return unless @builds;

    my $n = ($#builds > 2 ? 2 : $#builds);
    my @last_three_builds = @builds[0..$n];

    my @failed_builds = grep { $_->status eq 'Failed' } @last_three_builds;
    return (@failed_builds == 3 );
}


sub model_has_progressed {
    my $model = shift;

    my @builds = $model->builds;
    die unless (@builds > 1);

    my $latest_build = $model->latest_build;
    my %latest_status = workflow_status($latest_build);

    my $previous_build = previous_build($latest_build);
    my %previous_status = workflow_status($previous_build);

    my $status_are_different = status_compare(\%latest_status, \%previous_status);

    return $status_are_different;
}


sub latest_build_is_succeeded {
    my $model = shift;

    my $latest_build = $model->latest_build;

    return (
        $latest_build
        && $latest_build->status
        && $latest_build->status eq 'Succeeded'
    );
}


sub previous_build {
    my $build = shift;

    my $model = $build->model;
    my @prior_builds = grep { $_->id < $build->id } $model->builds;

    my $previous_build = @prior_builds ? $prior_builds[-1] : undef;
    return $previous_build;
}


sub workflow_status {
    my $build = shift;

    my $build_instance = $build->newest_workflow_instance;
    my @child_instances = $build_instance->sorted_child_instances if $build_instance;

    my %status;
    for my $child_instance (@child_instances) {
        (my $name = $child_instance->name) =~ s/^[0-9]+\s+//;
        $status{$name} = $child_instance->status;
    }

    return %status;
}


sub status_compare { # http://stackoverflow.com/q/540229
    my %a = %{ shift @_ };
    my %b = %{ shift @_ };
    for my $key (keys %a) {
          return 1 unless defined $b{$key} and $a{$key} eq $b{$key};
          delete $a{$key};
          delete $b{$key};
    }
    return 1 if keys %b;
    return 0;
}
