package Genome::Model::Command::Services::JobMonitor;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::Services::JobMonitor {
    is => 'Command',
};

sub help_brief {
    return <<EOS
executes scheduled steps, rescues failed jobs
EOS
}

sub help_synopsis {
    return <<EOS
genome-model services job-monitor
EOS
}

sub help_detail {
    return <<EOS 
Monitors and possibly launches jobs.
EOS
}

sub execute {
    my $self = shift;

    unless ($< == 10102) {
        die "This module should only be run by via cron.";
    }

    $DB::single = 1;

    my @launchable_events = Genome::Model::Event->get(
        event_status => 'Scheduled', # how did this get an uppercase everywhere?
        lsf_job_id => undef,
        ref_seq_id => undef,
        -order_by => ['model_id','date_scheduled'],
    );

    $self->_launch_events(@launchable_events);

    @launchable_events = Genome::Model::Event->get(
        event_status => 'Scheduled', # how did this get an uppercase everywhere?
        lsf_job_id => undef,
        run_id => undef,
        -order_by => ['model_id','-ref_seq_id'],
    );

    $self->_launch_events(@launchable_events);

    return 1;
}

sub _launch_events {
    my $self = shift;
    my @launchable_events = @_;
    
    my $last_event;
    while (my $event = shift @launchable_events) {
        if ( $last_event and ($event->model_id != $last_event->model_id) ) {
            $last_event = undef;
        }
        my $last_bsub_job_id = $self->Genome::Model::Event::run_command_with_bsub($event,$last_event);
        unless ($last_bsub_job_id) {
            $self->error_message("Error running bsub for event " . $event->id);
            # skip on to the events for the next model
            $last_event = $event;
            while ($event->model_id eq $last_event->model_id) {
                $self->warning_message("Skipping event " . $event->id . " due to previous error.");
                $event = shift @launchable_events;
                last if not defined $event;
            }
            redo;
        }
        $event->lsf_job_id($last_bsub_job_id);
        $last_event  = $event;
    }
}

1;
