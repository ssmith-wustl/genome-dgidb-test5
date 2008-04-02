package Genome::Model::Command::BsubRetry;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::BsubRetry {
    is => 'Command',
    has => [
        event_id            => { is => 'Integer', doc => 'Identifies the Genome::Model::Event by id'},
        prior_event_id      => { is => 'Integer', doc => 'Identifies the prior Genome::Model::Event by id', is_optional=>1 },
        model_id            => { is => 'Integer', doc => "Identifies the genome model on which we're operating, Used for validation" },
        model               => { is => 'Genome::Model', id_by => 'model_id' },
    ],
    has_optional => [
        reschedule          =>  { is => 'Boolean', doc => 'Allow completed jobs to run again' },
    ]
};

sub sub_command_sort_position { 100 }

sub help_brief {
    "Used by users to rerun previously schedule Events that failed on a blade"
}

sub help_synopsis {
    return <<"EOS"
genome-model bsub-retry --event-id 123456 --model_id 5
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

$DB::single=1;
    # Give the add-reads top level step a chance to sync database so these events
    # show up
    my $try_count = 10;
    my $event;
    while($try_count--) {
        $event = Genome::Model::Event->load(id => $self->event_id);
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

    unless ($event->model_id == $self->model_id) {
        $self->error_message("The model id for the loaded event ".$event->model_id.
                             " does not match the command line ".$self->model_id);
        return;
    }

    # Re-load the command object with the proper class.
    # FIXME Maybe Event.pm could be changed to do this for us at some point
    my $command_obj;
    my $proper_command_class_name = $event->class_for_event_type();
    {
        unless ($proper_command_class_name) {
            $self->error_message('Could not derive command class for command string '.$event->event_type);
            return;
        }
        $command_obj = $proper_command_class_name->get(genome_model_event_id => $event->genome_model_event_id);
    }

    # retry tests here

    ## create a dummy object to call this method, refactor candidate
    my $ar = Genome::Model::Command::AddReads->create(
        model_id => $self->model_id,
        sequencing_platform => 'solexa', # dont care
        full_path => '/tmp' # dont care
    );

    ## since i'm rerunning prior, set its job_id to me
    ## then run a new copy of the command i was supposed to run, dependent on my job_id
    ## finally set the command i should have ran to the new job_id

    my $old_lsf_job_id = $command_obj->lsf_job_id;
    my $job_id = $ar->run_command_with_bsub($command_obj);

    $ar->delete;  ## ditch the dummy

    $command_obj->lsf_job_id($job_id);
    $command_obj->event_status('Scheduled');
    $command_obj->date_scheduled(UR::Time->now());
    $command_obj->date_completed(undef);
    $command_obj->user_name($ENV{'USER'});

    UR::Context->commit();

    {
        my @all_scheduled = Genome::Model::Event->get(event_status => 'Scheduled', model_id => $self->model_id);
        foreach my $sched_event (@all_scheduled) {
            next if ($command_obj->lsf_job_id == $sched_event->lsf_job_id); # dont check me

            my ($sched_lsf_state, $sched_lsf_events) = $self->lsf_state($sched_event->lsf_job_id);

            if (exists $sched_lsf_events->[0]->[1]->{'Dependency Condition'} &&
                $sched_lsf_events->[0]->[1]->{'Dependency Condition'} =~ /^$old_lsf_job_id$/) {

                my $dep_lsf_job = $sched_event->lsf_job_id;

                my $bmod_out = `bmod -w $job_id $dep_lsf_job`;

            }
        }

    }

    1;
}

# utility function that parses bjobs long format
sub lsf_state {
    my ($self, $lsf_job_id) = @_;

    my $spool = `bjobs -l $lsf_job_id`;
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

