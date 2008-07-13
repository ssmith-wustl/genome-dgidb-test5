package Genome::Model::Command::ReLaunch;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::ReLaunch {
    is => 'Genome::Model::Command',
    has => [
        # model is implied by the base class
        'events_matching'    => { 
            is => 'String', 
            is_optional => 1,
            doc => 'all or part of the step name(s) which should be rescheduled' 
        },
    ],
};

sub sub_command_sort_position { 3 }

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
    $DB::single=1;
    my $self = shift;

    return unless ($self->SUPER::_execute_body(@_));    

    my $model = $self->model;
    unless ($model) {
        $self->error_message("No model!?");
    } 
   
    my $running_build_event = $model->running_build_event;
    unless ($running_build_event) {
        $self->error_message("No in-progress assembly event found.  Run a new one!");
        return;
    }

    my @e = Genome::Model::Event->get(
        model_id => $model->id,
        parent_event_id => $running_build_event->id,
        "event_type like" => $self->events_matching
    );

    my @lsf_jobs;
    for my $e (@e) {
        $e->event_status('Failed');
        push @lsf_jobs, $e->lsf_job_id if $e->lsf_job_id;
        print $e->id(), "\t", $e->event_type," for ref seq ",$e->ref_seq_id,"\n";
        my $next = $e;
        my $indent = 0;
        while ($next = Genome::Model::Event->get(prior_event => $next)) {
            $next->event_status('Failed');
            push @lsf_jobs, $next->lsf_job_id if $next->lsf_job_id;
            $indent ++;
            print ((" " x $indent) . $next->id(), "\t", $next->event_type,"\n");
        }
    }
    print "failed " . scalar(@e) . " processes and their subsequent steps.\n";
 
    # TODO: make this more robuts 
    system "bkill @lsf_jobs";      

    return Genome::Model::Command::Services::JobMonitor->execute(model_id => $model->id);
}

1;

