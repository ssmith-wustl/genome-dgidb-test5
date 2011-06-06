package Genome::Model::Command::Services::BuildQueuedModels2;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Services::BuildQueuedModels2 {
    is => 'Genome::Command::Base',
    doc => "Build queued models.",
    has_optional => [
        max_scheduled_builds => {
            is => 'Integer',
            default => 50,
        },
    ],
};

sub help_synopsis {
    return <<EOS;
genome model services build-queued-models
EOS
}

sub help_detail {
    return <<EOS;
Builds queued models.
EOS
}

sub execute {
    my $self = shift;

    my $lock_resource = '/gsc/var/lock/genome_model_services_builed_queued_models_2';

    my $lock = Genome::Sys->lock_resource(resource_lock => $lock_resource, max_try => 1);
    unless ($lock) {
        $self->error_message("Could not lock, another instance of BQM must be running.");
        return;
    }

    UR::Context->add_observer(
        aspect => 'commit',
        callback => sub{ Genome::Sys->unlock_resource(resource_lock => $lock) },
    );

    my $max_builds_to_start = $self->num_builds_to_start;
    unless ($max_builds_to_start) {
        $self->status_message("There are already " . $self->max_scheduled_builds . " builds scheduled.");
        return 1;
    }
    $self->status_message("Will try to start up to $max_builds_to_start builds.");
    
    my $models = Genome::Model->create_iterator(
        build_requested => '1',
    );

    my @errors;
    my $builds_started = 0;
    my $total_count = 0;
    while (my $model = $models->next) {
        if ($builds_started >= $max_builds_to_start){
            $self->status_message("Already started max builds $builds_started, quitting...");
            last; 
        }

        $self->status_message("Trying to start " . $model->__display_name__ . "...");
        $total_count++;
        
        my $transaction = UR::Context::Transaction->begin();
        my $build = eval {
            my $build = $model->create_build(model_id => $model->id);
            unless ($build) {
                die $self->error_message("Failed to create build for model (".$model->name.", ID: ".$model->id.").");
            }

            my $build_started = $build->start;
            unless ($build_started) {
                die $self->error_message("Failed to start build (" . $build->__display_name__ . "): $@.");
            }
            return $build;
        };
        if ($build and $transaction->commit) {
            $self->status_message("Successfully started build (" . $build->__display_name__ . ").");
            $builds_started++;
        }
        else {
            push @errors, $model->__display_name__ . ": " . $@;
            $transaction->rollback;
        }
    }

    my $expected_count = ($max_builds_to_start > $total_count ? $total_count : $max_builds_to_start);
    $self->display_summary_report($total_count, @errors);
    $self->status_message('   Expected: ' . $expected_count);

    return !scalar(@errors);
}


sub num_builds_to_start {
    my $self = shift;
    
    my $scheduled_builds = Genome::Model::Build->create_iterator(
        run_by => Genome::Sys->username,
        status => 'Scheduled',
    );
    
    my $scheduled_build_count = 0;
    while ($scheduled_builds->next && ++$scheduled_build_count < $self->max_scheduled_builds) { 1; }
    
    return ($self->max_scheduled_builds - $scheduled_build_count);
}


1;
