package Genome::Model::Command::ReLaunch;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::ReLaunch {
    is => 'Genome::Model::Command',
    has => [
        # model is implied by the base class
        'events_matching'    => { 
            is => 'String', 
            is_optional => 1,
            doc => 'all or part of the step name(s) which should be rescheduled' 
        },
        'event_id' => { 
            is => 'Number',
            is_optional => 1,
            doc => 'the id to re-schedule, includeing downstream steps.'
        },
    ],
};

sub sub_command_sort_position { 5 }

sub help_brief {
    "re-launch all of the steps (stage 2) for a given model"
}

sub help_synopsis {
    return <<'EOS'
genome-model re-launch tumor%98%v0b --events-matching %update-genotype% 

EOS
}

sub help_detail {
    return <<"EOS"
Take all of the events under 
EOS
}

sub execute {
    $DB::single = $DB::stopper;
    my $self = shift;

    return unless ($self->SUPER::_execute_body(@_));    

    my $model = $self->model;
    unless ($model) {
        $self->error_message("No model!?");
    } 
   
    my $running_build_event = $model->running_build_event;
    unless ($running_build_event) {
        $self->error_message("No in-progress build event found.  Run a new build to get new results.");
        return;
    }

    # get everything specified on the cmdline, or else everything which is at the start of a series of steps
    my @e;
    if ($self->event_id) {
        @e = Genome::Model::Event->get($self->event_id);
        unless (@e) {
            $self->error_message("Event " . $self->event_id . " not found!");
            return;
        }
        unless ($e[0]->model_id eq $self->model_id) {
            $self->error_message("Event " . $e[0]->event_id
                . " is for model " . $e[0]->model->name . " (" . $e[0]->model_id . ")"
                . " but the specified model was " . $model->name . " (" . $self->model_id . ")!"
            );
            return;
        }
    }
    else {
        if ($self->events_matching) {
            @e = Genome::Model::Event->get(
                model_id => $model->id,
                parent_event_id => $running_build_event->id,
                ($self->events_matching ? ("event_type like" => $self->events_matching) : (prior_event_id => undef) )
            );
        }
        else {
            @e = Genome::Model::Event->get(
                model_id => $model->id,
                parent_event_id => $running_build_event->id,
                prior_event_id => undef
            );
        }
        $self->status_message("Found " . scalar(@e) . " events to re-launch.");
    }
    my @lsf_jobs;
    for my $e (@e) {
        unless ($e->revert) {
            $self->error_message("Error reverting " . $e->desc . ": " . $e->error_message . " ...skipping resubmit.");
            next;
        }
        $e->event_status('Failed');
        push @lsf_jobs, $e->lsf_job_id if $e->lsf_job_id;
        print $e->id(), "\t", $e->event_type," for ref seq ",$e->ref_seq_id,"\n";
        my $next = $e;
        my $indent = 0;
        while ($next = Genome::Model::Event->get(prior_event => $next)) {
            $next->event_status('Failed');
            unless ($next->revert) {
                $self->error_message("Error reverting " . $next->desc . ": " . $next->error_message . " ...skipping resubmit.");
                next;
            }
            push @lsf_jobs, $next->lsf_job_id if $next->lsf_job_id;
            $indent ++;
            print ((" " x $indent) . $next->id(), "\t", $next->event_type,"\n");
        }
    }
 
    # TODO: make this more robuts 
    $self->status_message("LSF jobs to kill or verify are killed: " . scalar(@lsf_jobs) . "\n") if @lsf_jobs;
    system "bkill @lsf_jobs";      

    $self->status_message("Launching LSF jobs for the model " . $model->name . " (id " . $model->id . ")\n");
    $self->status_message("Monitor jobs at: http://gscweb/cgi-bin/solexa/genome-model-stage2.cgi?model-name=" . $model->name . "&refresh=1");
    return Genome::Model::Command::RunJobs->execute(model_id => $model->id);
}

1;

