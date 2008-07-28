package Genome::Model::Command::List::Jobs;

use strict;
use warnings;

use above "Genome";
use GSC;
use Command; 
use Data::Dumper;
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use IO::File;

use Date::Manip;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        done => { type => 'Boolean', doc => 'Include info for successfully completed jobs', is_optional => 1 },
        user => { type => 'String', doc => 'Show info for jobs owned by this user instead of your own.  Use "all" to show jobs by every user', is_optional => 1 },
        model_name => { type => 'String', doc => 'Show only jobs for this model name', is_optional => 1 },
        model_id   => { type => 'String', doc => 'Show only jobs for this model id', is_optional => 1 },
    ],
);

sub help_brief {
    "list the status of Genome Model analysis jobs";
}

sub help_synopsis {
    return <<"EOS"
genome-model list jobs
EOS
}

sub help_detail {
    return <<"EOS"
Lists information about genome-model related jobs.  By default, it only prints information on scheduled, running or failed jobs.
EOS
}


sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my @get_args;
    if ($self->user and $self->user eq 'all') {
        ;
    } elsif ($self->user) {
        push(@get_args, 'user_name' => $self->user);
    } else {
        push(@get_args, 'user_name' => $ENV{'USER'});
    }

    my @model_objs;
    if ($self->model_name) {
        @model_objs = Genome::Model->get(name => $self->model_name);
    } elsif ($self->model_id) {
        @model_objs = Genome::Model->get(genome_model_id => $self->model_id);
    }
    if (@model_objs) {
        push @get_args, 'model_id', [map { $_->id } @model_objs];
    }

    my @statuses = ('Running', 'Scheduled', 'Failed', 'Crashed');
    if ($self->done) {
        push @statuses, 'Succeeded';
    } 
    push @get_args, 'event_status', \@statuses;

    my @events = Genome::Model::Event->get(@get_args);
    my %events_by_status;
    foreach my $event ( @events ) {
        push @{$events_by_status{$event->event_status}}, $event;
    }

    
    if ($self->done) {
        # Only show jobs done in the last day
        my $start_date = Date::Manip::ParseDate("yesterday");
        my @done_jobs = grep { Date::Manip::Date_Cmp($start_date, Date::Manip::ParseDate($_->date_completed)) <= 0 }
                        @{$events_by_status{'Succeeded'}};

        print "Done Events in the last 24 hours:\n";
        $self->_summarize_jobs(@done_jobs);
        print "\n";
    }


    print "Running jobs:\n";
    $self->_summarize_jobs(@{$events_by_status{'Running'}}, @{$events_by_status{'Scheduled'}});

    print "\nFailed Jobs:\n";
    $self->_summarize_jobs(@{$events_by_status{'Failed'}}, @{$events_by_status{'Crashed'}});

    return 1;
}

sub _summarize_jobs {
    my($self, @events) = @_;

    my $job_info = $self->_get_job_info(map {$_->lsf_job_id} @events);

    my $any_orphaned = 0;
    my $any_without_retries = 0;
    print("JobID     User     Status     Model                       Run Path                            Command\n");
    foreach my $event ( @events ) {
        my $jobid = $event->lsf_job_id || '<none>';
        my $model = $event->model;
        my $run = $event->run;

        my $max_retries;
        {
            my $proper_command_class_name = $event->class_for_event_type();
            my $command_obj;
            if ($proper_command_class_name) {
                eval {
                    $command_obj = $proper_command_class_name->get(genome_model_event_id => $event->genome_model_event_id);
                };
                if ($@) {
                    $command_obj = $event;
                };
            } else {
                # weird case because of test classes that may end up in the db, just use the event obj
                $command_obj = $event;
            }
            $max_retries = $command_obj->can('max_retries') ? $command_obj->max_retries : 0;
        }

        my $this_job_info = $job_info->{$jobid};
        if ($event->event_status eq 'Running' and !$this_job_info) {
            $jobid .= '*';
            $any_orphaned = 1;
        }

        ## older events have null retry_count, they will never be retried
        if (!defined($event->retry_count) or $event->retry_count >= $max_retries) {
            $jobid .= '~';
            $any_without_retries = 1;
        }
        printf("%-9s %-8s %-10s %-27s %-35s %s\n",
               $jobid,
               $this_job_info->{'user'} || $event->user_name || '<unknown>',
               $this_job_info->{'stat'} || $event->event_status || 'running',
               $model->name,
               substr($run->full_path, -35),
               $event->event_type || '<unknown>',
            );
    }
    if ($any_orphaned) {
        print "* denotes an event listed as 'Running' but the LSF job no longer exists\n";
    }
    if ($any_without_retries) {
        print "~ denotes an event without any remaining automatic retries\n";
    }

    return 1;
}



sub _get_job_info {
    my($self,@jobids) = @_;

    my $arg = join(' ',grep { $_ } @jobids);
    return {} unless $arg;

    my $fh = IO::File->new("bjobs -w $arg 2>/dev/null |");

    my $header_line = $fh->getline();

    my $job_info;
    while (<$fh>) {
        next if (m/is not found/);  # unknown job id
        chomp;

        my @fields = split(/\s+/);

        my %info;
        $info{'jobid'} = shift @fields;
        $info{'user'} = shift @fields;
        $info{'stat'} = shift @fields;
        $info{'queue'} = shift @fields;
        $info{'from_host'} = shift @fields;
        $info{'exec_host'} = shift @fields;
        $info{'submit_time'} = join(' ', splice(@fields, -3, 3));
        $info{'job_name'} = join(' ',@fields);

        $job_info->{$info{'jobid'}} = \%info;
    }
    return $job_info;
}

1;

