package Genome::Model::Command::BsubRetry;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::BsubRetry {
    is => 'Command',
    has => [
        event_id            => { is => 'Integer', is_optional => 1, doc => 'Identifies the Genome::Model::Event by id'},
        job_id              => { is => 'Integer', is_optional => 1, doc => 'Identifies the Genome::Model::Event by lsf jobID'},
        prior_event_id      => { is => 'Integer', doc => 'Identifies the prior Genome::Model::Event by id', is_optional=>1 },
    ],
    has_optional => [
        reschedule          =>  { is => 'Boolean', doc => 'Allow completed jobs to run again' },
        bsub_queue          =>  { is => 'String',
                                  doc => 'Which bsub queue to use for sub-command jobs, default is whatever queue it was originally scheduled into', },
                                  

    ]
};

sub sub_command_sort_position { 100 }

sub help_brief {
    "Used by users to rerun previously schedule Events that failed on a blade"
}

sub help_synopsis {
    return <<"EOS"
genome-model bsub-retry --event-id 123456
EOS
}

sub help_detail {
    return <<"EOS"
This command loads an already existing Event and executes it on a blade.  If the indicated event is
in a 'Succeeded' state, it will refuse to run.  The --reschedule flag will override this behavior.  The
event is placed in the Scheduled state, rerun on the blade and all depedencies rewritten.
EOS
}


sub execute {
    my $self = shift;

    umask 0022;

$DB::single=1;
    # Give the add-reads top level step a chance to sync database so these events
    # show up
    my %get_args;
    if ($self->event_id) {
        $get_args{'genome_model_event_id'} = $self->event_id;
    } elsif ($self->job_id) {
        $get_args{'lsf_job_id'} = $self->job_id;
    } else {
        $self->error_message('Either --event-id or --job-id is required');
        return;
    }

    my $try_count = 10;
    my $event;
    while($try_count--) {
        $event = Genome::Model::Event->load(%get_args);
        last if ($event);
        sleep 5;
    }
    unless ($event) {
        $self->error_message('No event found with id '.$self->event_id);
        return;
    }
    if (($event->event_status and $event->event_status eq 'Succeeded') and ! $self->reschedule) {
        $self->error_message("Refusing to re-run event with status ".$event->event_status);
        return;
    }

    my $command_obj = $event;
    
    # What lsf queue should it get rescheduled in to
    my %add_reads_queue;
    if ($self->bsub_queue) {
        $add_reads_queue{'bsub_queue'} = $self->bsub_queue;
    } else {
        my ($old_jobinfo, $old_events) = $self->lsf_state($event->lsf_job_id);
        if ($old_jobinfo && $old_jobinfo->{'Queue'}) {
            $add_reads_queue{'bsub_queue'} = $old_jobinfo->{'Queue'};
        }
    }

    my $old_lsf_job_id = $command_obj->lsf_job_id;
    my $job_id = $command_obj->execute_with_bsub(%add_reads_queue);

    $command_obj->retry_count($command_obj->retry_count + 1);
    $command_obj->lsf_job_id($job_id);
    $command_obj->event_status('Scheduled');
    $command_obj->date_scheduled(UR::Time->now());
    $command_obj->date_completed(undef);
    $command_obj->user_name($ENV{'USER'});

    UR::Context->commit();

    $self->status_message("Job rescheduled as jobid $job_id: ".$event->event_type);

    my @all_scheduled = Genome::Model::Event->get(event_status => 'Scheduled', model_id => $event->model_id, run_id => $command_obj->run_id);
    foreach my $sched_event (@all_scheduled) {
        next if ($command_obj->lsf_job_id == $sched_event->lsf_job_id); # dont check me
        if (my ($sched_lsf_state, $sched_lsf_events) = $self->lsf_state($sched_event->lsf_job_id)) {
            if (exists $sched_lsf_events->[0]->[1]->{'Dependency Condition'}) {
                my $queue = $add_reads_queue{'bsub_queue'};
                if ($sched_lsf_events->[0]->[1]->{'Dependency Condition'} =~ /^(ended|done)\($old_lsf_job_id\)$/) {
                    my $dep_lsf_job = $sched_event->lsf_job_id;
                $self->status_message("Changing dependancy of jobid $dep_lsf_job from $old_lsf_job_id to $job_id");
                    my $bmod_out = `bmod -q $queue -w '$1($job_id)' $dep_lsf_job`;
                } elsif ($sched_lsf_events->[0]->[1]->{'Dependency Condition'} =~ /^$old_lsf_job_id$/) {
                    ## handle old behavior
                    my $dep_lsf_job = $sched_event->lsf_job_id;
                $self->status_message("Changing dependancy of jobid $dep_lsf_job from $old_lsf_job_id to $job_id");
                    my $bmod_out = `bmod -q $queue -w $job_id $dep_lsf_job`;
                }

            }
        }
    }

    1;
}

# utility function that parses bjobs long format
sub lsf_state {
    my ($self, $lsf_job_id) = @_;

    my $spool = `bjobs -l $lsf_job_id 2>&1`;
    return if ($spool =~ /Job <$lsf_job_id> is not found/);

    # this regex nukes the indentation and line feed
    $spool =~ s/\s{22}//gm; 

    my @eventlines = split(/\n/, $spool);
    shift @eventlines unless ($eventlines[0] =~ m/\S/);  # first line is white space
    
    my $jobinfoline = shift @eventlines;
    # sometimes the prior regex nukes the white space between Key <Value>
    $jobinfoline =~ s/(?<!\s{1})</ </g;

    my %jobinfo = ();
    # parse out a line such as
    # Key <Value>, Key <Value>, Key <Value>
    while ($jobinfoline =~ /(?:^|(?<=,\s{1}))(.+?)(?:\s+<(.*?)>)?(?=(?:$|;|,))/g) {
        $jobinfo{$1} = $2;
    }

    my @events = ();
    foreach my $el (@eventlines) {
        $el =~ s/(?<!\s{1})</ </g;

        my $time = substr($el,0,21,'');
        substr($time,-2,2,'');

        # see if we really got the time string
        if ($time !~ /\w{3}\s+\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}/) {
            # there's stuff we dont care about at the bottom, just skip it
            next;
        }

        my @entry = (
            $time,
            {}
        );

        while ($el =~ /(?:^|(?<=,\s{1}))(.+?)(?:\s+<(.*?)>)?(?=(?:$|;|,))/g) {
            $entry[1]->{$1} = $2;
        }
        push @events, \@entry;
    }


    return (\%jobinfo, \@events);
}

1;

