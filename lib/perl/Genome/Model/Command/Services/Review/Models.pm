package Genome::Model::Command::Services::Review::Models;

class Genome::Model::Command::Services::Review::Models {
    is => 'Genome::Command::Base',
    doc => 'Tool for the Cron Tzar to review builds, e.g. missing builds, failed builds, etc.',
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            shell_args_position => 1,
        },
    ],
};

use strict;
use warnings;
use Genome;

sub execute {
    my $self = shift;

    my $user = getpwuid($<);

    my @models = $self->models;

    my %models = map { my $model_id = $_->id; $model_id => $_; } @models;

    my %action = map { $_ => '-' } keys %models;
    for my $model_id (keys %models) {
        my $model = $models{$model_id};

        my @builds = $model->builds;
        @builds = grep { $_->run_by eq $user } @builds;
        @builds = @builds[-3..-1] if (@builds > 3);

        my @bad_builds = grep { $_->status eq 'Failed' or $_->status eq 'Abandoned' } @builds;
        my $latest_build = $model->latest_build;
        my $current_version = $self->current_version();
        my @instrument_data = $model->instrument_data;

        if (@builds == 0) {
            $action{$model_id} = 'start new build';
            next;
        }
        if ($latest_build->status eq 'Succeeded') {
            $action{$model_id} = 'remove old fails';
            next;
        }
        if (@bad_builds >= 3) {
            $action{$model_id} = 'investigate';
            next;
        }
        if ($latest_build->status eq 'Scheduled') {
            $action{$model_id} = 'already scheduled';
            next;
        }
        if ($latest_build->status eq 'Running') {
            $action{$model_id} = 'already running';
            next;
        }
        if (@instrument_data == 0) {
            $action{$model_id} = 'assign instrument data';
            next;
        }
        if ($latest_build->status eq 'Abandoned') {
            $action{$model_id} = 'start new build';
            next;
        }
        if ($latest_build->status eq 'Failed') {
            if ($latest_build->software_revision =~ /$current_version/) {
                $action{$model_id} = 'restart build';
                next;
            }
            else {
                $action{$model_id} = 'start new build';
                next;
            }
        }
    }

    for my $model_id (keys %models) {
        print "$model_id\t" . $action{$model_id} . "\n";
    }

    return 1;
}

sub current_version {
    my $self = shift;
    my $symlink_path = readlink('/gsc/scripts/opt/genome/current/pipeline') || die;
    my $version = (split('/', $symlink_path))[-1];
}
