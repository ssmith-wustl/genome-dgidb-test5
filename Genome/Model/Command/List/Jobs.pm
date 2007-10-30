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

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
         done => { type=> 'boolean', is_optional => 1, doc => 'Include info for completed jobs' },
         user => { type => 'string', is_optional => 1, doc => 'Show info for jobs owned by this user insetad of your own.  Use "all" to show jobs by every user' },
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
Lists information about bsub-ed jobs.  By default, it only prints information on running or failed jobs.
EOS
}


sub execute {
    my $self = shift;

    $DB::single=1;

    my @get_args;
    if ($self->user and $self->user eq 'all') {
        ;
    } elsif ($self->user) {
        push(@get_args, 'user_name' => $self->user);
    } else {
        push(@get_args, 'user_name' => $ENV{'USER'});
    }

    # Get jobs currently running
    my @jobs = Genome::Model::Event->get(@get_args, date_completed => undef);
    
    # failed jobs, too
    my @failed_jobs = Genome::Model::Event->get(@get_args, event_status => 'Failed');

    my @done_jobs = Genome::Model::Event->get(@get_args, event_status => 'Succeeded');
    unless ($self->done) {
        # Only show jobs done in the last day
        my $start_date = Date::Manip::ParseDate("yesterday");
        @done_jobs = grep { Date::Manip::Date_Cmp($start_date, Date::Manip::ParseDate($_->date_completed)) <= 0 } @done_jobs;
    }

    foreach my $stuff ( ['Done jobs:', \@done_jobs],
                        ['Currently running jobs:', \@jobs],
                        ['Failed jobs:', \@failed_jobs],
                      ) {

        if (@{$stuff->[1]}) {
            $self->_summarize_jobs(@$stuff);
            print "\n";
        }
    }

    return 1;
}

sub _summarize_jobs {
    my($self, $header, $events) = @_;

    print "$header\n";

    my $job_info = $self->_get_job_info(map {$_->lsf_job_id} @$events);

    print("JobID    User     Status     Model                  Run Path                       Command\n");
    foreach my $event ( @$events ) {
        my $jobid = $event->lsf_job_id || '<none>';
        my $model = $event->model;
        my $run = $event->run;

        my $this_job_info = $job_info->{$jobid};
        printf("%-8s %-8s %-10s %-22s %-30s %s\n",
               $jobid,
               $this_job_info->{'user'} || $event->user_name || '<unknown>',
               $this_job_info->{'stat'} || $event->event_status || 'running',
               $model->name,
               substr($run->full_path, -30),
               $event->event_type || '<unknown>',
            );
    }

    return 1;
}



sub _get_job_info {
    my($self,@jobids) = @_;

    my $arg = join(' ',grep { $_ } @jobids);
    return {} unless $arg;

    my $fh = IO::File->new("bjobs $arg 2>/dev/null |");

    $fh->getline();  # Throw away the header info

    my $job_info;
    while (<$fh>) {
        next if (m/is not found/);  # unknown job id
        chomp;

        my $info = {};
        @$info{'jobid', 'user', 'stat', 'queue', 'from_host', 'exec_host', 'job_name', 'submit_time'} = split(/\s\s+/, $_);
        $job_info->{$info->{'jobid'}} = $info;
    }
    return $job_info;
}

1;

