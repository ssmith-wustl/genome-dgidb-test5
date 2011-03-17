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
    ],
};

use strict;
use warnings;
use Genome;

sub execute {
    my $self = shift;

    my @models = $self->models;

    my %models = map { my $model_id = $_->id; $model_id => $_; } @models;

    my %action = map { $_ => '-' } keys %models;
    for my $model_id (keys %models) {
        my $model = $models{$model_id};

        my @builds = $model->builds;
        @builds = grep { $_->run_by eq 'apipe-builder' || $_->run_by eq 'ebelter' } @builds;
        @builds = @builds[-3..-1] if (@builds > 3);

        my @bad_builds = grep { $_->status eq 'Failed' or $_->status eq 'Abandoned' } @builds;
        my $latest_build = $model->latest_build;
        my $current_version = $self->current_version();
        my @instrument_data = $model->instrument_data;

        if (my $known_issue = $self->known_issue($model)) {
            $self->print_action_for_model($model, $known_issue);
            next;
        }
        if (@builds == 0) {
            $self->print_action_for_model($model, 'start new build');
            next;
        }
        if ($latest_build->status eq 'Succeeded') {
            $self->print_action_for_model($model, 'remove old fails');
            next;
        }
        if (@bad_builds >= 3) {
            $self->print_action_for_model($model, 'investigate');
            next;
        }
        if ($latest_build->status eq 'Scheduled') {
            $self->print_action_for_model($model, 'already scheduled');
            next;
        }
        if ($latest_build->status eq 'Running') {
            $self->print_action_for_model($model, 'already running');
            next;
        }
        if (@instrument_data == 0) {
            $self->print_action_for_model($model, 'assign instrument data');
            next;
        }
        if ($latest_build->status eq 'Abandoned') {
            $self->print_action_for_model($model, 'start new build');
            next;
        }
        if ($latest_build->status eq 'Failed') {
            if ($latest_build->software_revision && $latest_build->software_revision =~ /$current_version/) {
                $self->print_action_for_model($model, 'restart build');
                next;
            }
            else {
                $self->print_action_for_model($model, 'start new build');
                next;
            }
        }
    }

    return 1;
}

sub print_action_for_model {
    my $self = shift;
    my $model = shift;
    my $action = shift;
    
    my $model_id = $model->id;
    my $pp_name = $model->processing_profile->name;

    print "$model_id\t$pp_name\t" . $action . "\n";

    return 1;
}

sub current_version {
    my $self = shift;
    my $symlink_path = readlink('/gsc/scripts/opt/genome/current/pipeline') || die;
    my $version = (split('/', $symlink_path))[-1];
}

sub known_issue {
    my $self = shift;
    my $model = shift;

    if ($model->region_of_interest_set_name && $model->region_of_interest_set_name eq 'hg18 nimblegen exome version 2') {
        return 'known issue: feature list, hg18 nimblegen exome version 2, contains chromosome not in human 36';
    }
    if ($model->region_of_interest_set_name && $model->region_of_interest_set_name eq 'hg19 nimblegen exome version 2') {
        return 'known issue: feature list, hg19 nimblegen exome version 2, contains chromosome not in GRCh37-lite-build37';
    }

    return;
}
