package Genome::Model::Command::Services::BuildQueuedModels;

use strict;
use warnings;

use Genome;

use POSIX qw(ceil);

class Genome::Model::Command::Services::BuildQueuedModels {
    is => 'Genome::Command::Base',
    doc => "Build queued models.",
    has_optional => [
        max_scheduled_builds => {
            is => 'Integer',
            default => 50,
        },
        channels => {
            is => 'Integer',
            default => 1,
            doc => 'number of "channels" to parallelize models by',
        },
        channel => {
            is => 'Integer',
            default => 0,
            doc => 'zero-based channel to use',
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

    unless ($self->channel < $self->channels) {
        die $self->error_message('--channel must be less than --channels');
    }

    my $lock_resource = '/gsc/var/lock/genome_model_services_builed_queued_models_' . $self->channel . '_' . $self->channels;

    my $lock = Genome::Sys->lock_resource(resource_lock => $lock_resource, max_try => 1);
    unless ($lock) {
        $self->error_message("Could not lock, another instance of BQM must be running.");
        return;
    }

    my $context = UR::Context->current;
    $context->add_observer(
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
        next unless ($model->id % $self->channels == $self->channel);
        if ($builds_started >= $max_builds_to_start){
            $self->status_message("Already started max builds $builds_started, quitting...");
            last; 
        }

        $self->status_message("Trying to start #" . ($builds_started + 1) . ': ' . $model->__display_name__ . "...");
        $total_count++;
        
        my $transaction = UR::Context::Transaction->begin();
        my $build = eval {
            my $build = Genome::Model::Build->create(model_id => $model->id);
            unless ($build) {
                die $self->error_message("Failed to create build for model (".$model->name.", ID: ".$model->id.").");
            }
            return $build;
        };
        if($build and $transaction->commit()) {
            my $start_transaction = UR::Context::Transaction->begin();
            my $build_started = eval { $build->start; };
            if ($build_started) {
                $builds_started++;
                $self->status_message("Successfully started build (" . $build->__display_name__ . ").");
            }
            else {
                push @errors, $self->error_message("Failed to start build (" . $build->__display_name__ . "): " . ($@ || $build->error_message));
            }
            unless($start_transaction->commit()) {
                push @errors, $self->error_message("Failed to commit start transaction for build " . $build->__display_name__);
                $start_transaction->rollback();
            }
        }
        else {
            push @errors, $model->__display_name__ . ": " . $@;
            $transaction->rollback();
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
    while ($scheduled_builds->next && ++$scheduled_build_count <= $self->max_scheduled_builds) { 1; }
    
    my $max_per_channel = int($self->max_scheduled_builds / $self->channels);
    if ($scheduled_build_count >= $self->max_scheduled_builds) {
        return 0;
    }
    elsif (($scheduled_build_count + $max_per_channel) > $self->max_scheduled_builds) {
        return ceil($max_per_channel / $self->channels);
    }
    else {
        return $max_per_channel;
    }
}


1;
