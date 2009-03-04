package Genome::Model::Command::BsubHelper;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::BsubHelper {
    is => 'Command',
    has => [
        event_id            => { is => 'Integer', doc => 'Identifies the Genome::Model::Event by id'},
        model_id            => { is => 'Integer', doc => "Identifies the genome model on which we're operating, Used for validation" },
        model               => { is => 'Genome::Model', id_by => 'model_id' },
    ],
    has_optional => [
        reschedule          =>  { is => 'Boolean', doc => 'Allow completed jobs to run again' },
    ]
};

sub sub_command_sort_position { 100 }

sub help_brief {
    "Used by add-reads to run previously schedule Events on a blade"
}

sub help_synopsis {
    return <<"EOS"
genome-model bsub-helper --event-id 123456 --model_id 5
EOS
}

sub help_detail {
    return <<"EOS"
This command is run on a blade, and loads an already existing Event and executes it.  If the indicated event is
not in a 'Scheduled' state, it will refuse to run.  The --reschedule flag will override this behavior.
EOS
}


sub execute {
    my $self = shift;

    # Running statement for standard output and error, should print to appropriate files
    for my $handle ( *STDOUT, *STDERR )
    {
        print( $handle sprintf("Running execute at %s\n", UR::Time->now) );
    }

    umask 0022;

$DB::single = $DB::stopper;
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
    if (($event->event_status and $event->event_status !~ /Scheduled|Waiting/) and ! $self->reschedule) {
        $self->error_message("Refusing to re-run event with status ".$event->event_status);
        return;
    }

    unless ($event->verify_prior_event) {
        my $prior_event =  $event->prior_event;
        $self->error_message('Prior event did not verify: '. $prior_event->genome_model_event_id .' '.
        $prior_event->event_status);
        $event->date_completed(undef);
        $event->event_status('Failed');
        $event->user_name($ENV{'USER'});
        return;
    }

    unless ($event->model_id == $self->model_id) {
        $self->error_message("The model id for the loaded event ".$event->model_id.
                             " does not match the command line ".$self->model_id);
        return;
    }
    
    my $command_obj = $event;
    $command_obj->revert;

    unless ($command_obj->lsf_job_id) {
        $command_obj->lsf_job_id($ENV{'LSB_JOBID'});
    }
    $command_obj->date_scheduled(UR::Time->now());
    $command_obj->date_completed(undef);
    $command_obj->event_status('Running');
    $command_obj->user_name($ENV{'USER'});

    UR::Context->commit();

    my $rv;
    eval { $rv = $command_obj->execute(); };

    $command_obj->date_completed(UR::Time->now());
    if ($@) {
        $self->error_message($@);
        $command_obj->event_status('Crashed');
    } elsif($rv <= 1) {
        $command_obj->event_status($rv ? 'Succeeded' : 'Failed');
    }elsif($rv == 2) {
        $command_obj->event_status('Waiting');
    }
    else {
        $self->status_message("Unhandled positive return code: $rv...setting Succeeded");
        $command_obj->event_status('Succeeded');
    }


    return $rv;
}

# utility function that parses bjobs long format
sub lsf_state {
    my ($self, $lsf_job_id) = @_;

    my $spool = `bjobs -l $lsf_job_id 2>&1`;
    return if ($spool =~ /Job <$lsf_job_id> is not found/);

    # this regex nukes the indentation and line feed    
    $spool =~ s/\s{22}//gm; 

    my @eventlines = split(/\n/, $spool);
    shift @eventlines;  # first line is white space
    my %jobinfo = ();
    
    my $jobinfoline = shift @eventlines;
    if (defined $jobinfoline) {
        # sometimes the prior regex nukes the white space between Key <Value>
        $jobinfoline =~ s/(?<!\s{1})</ </g;
        # parse out a line such as
        # Key <Value>, Key <Value>, Key <Value>
        while ($jobinfoline =~ /(?:^|(?<=,\s{1}))(.+?)(?:\s+<(.*?)>)?(?=(?:$|;|,))/g) {
            $jobinfo{$1} = $2;
        }
    }
    my @pending_reasons = ();
    foreach my $line (@eventlines) {
        if ($line =~ /PENDING REASONS:/) {
            @pending_reasons = (
                                UR::Time->now,
                                {}
                            );
            next;
        }
        if (scalar(@pending_reasons)) {
            if ($line =~ /^\s*$/) {
                last;
            }
            $line =~ s/^\s+//;
            $pending_reasons[1]->{'PENDING REASON'} = $line;
        }
    }

    my @events = ();
    foreach my $el (@eventlines) {
        $el =~ s/(?<!\s{1})</ </g;

        my $time = substr($el,0,21,'');
        substr($time,-2,2,'');

        # see if we really got the time string
        if ($time !~ /\w{3} \w{3}\s+\d{1,2}\s+\d{1,2}:\d{2}:\d{2}/) {
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
    if (scalar(@pending_reasons)) {
        push @events, \@pending_reasons;
    }
    return (\%jobinfo, \@events);
}



1;


