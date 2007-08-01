package CSP::Job;

#-- this is an object that has everything you'd ever want to know about a job that is in the scheduled-confirming-confirm state
use strict;
use warnings;
use base 'App::Accessor';

CSP::Job->accessorize qw(job_id user status queue from_host exec_host submit_time debug_job);


sub new{
    my $class = shift;
    my %p = @_;
    
    my $self = {};
    bless $self, $class;
    
    $self->job_id(delete $p{job_id});
    unless($self->job_id){
	warn "No job id specified.  failed";
	return;
    }

    if($self->job_id =~ /\D/){ #--- debugging.  Not really a job
	$self->debug_job(1);
	my ($user, $host) = $self->job_id =~ /^(\w+)\@(\w+)/;
	$self->user($user);
	$self->exec_host($host);
    }
    elsif(!%p){
	my @l = CSP->run_blade_cmd('bjobs '.$self->job_id);
	return unless @l;

	my $ref = $self->process_line($l[1]);
	return unless $ref;  #-- sure, you give me an id, but nothing's there
	%p = %$ref;
    }
    
    return unless %p;
    while(my ($key, $value) = each %p){
	$self->$key($value);
    }
    return $self;
}

sub new_from_line{
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my $rf = $self->process_line(shift);
    while(my ($key, $value) = each %$rf){
	$self->$key($value);
    }
    return $self;
}

sub process_line{
    my $class = shift;
    my $line = shift;
    return unless $line;
    my @array = split /\.?\s+/, $line;
    $array[$#array - 2] .= ' '.$array[$#array - 1].' '.$array[$#array];
    splice (@array, $#array - 1, 2);
    
    my $ref = {
	job_id => $array[0],
	user => $array[1],
	status => $array[2],
	queue => $array[3],
	from_host => $array[4],
	submit_time => $array[$#array],
    };
    #--- "pending" statuses have no exec host
    if($ref->{status} ne 'PEND'){
	$ref->{exec_host} = $array[5];
    }
    
    return $ref;
}

sub refresh{
    #-- updates the job.  
    #   returns -1 if the job is no longer active.
    #   returns undef if the blade center is down
    #   returns 1 if the job has changed since refresh/creation
    #   returns 0 if there has been no change

    my $self = shift;
    return unless $self->job_id;
    my @line = CSP->run_blade_cmd('bjobs '.$self->job_id);
    if(@line){
	my $rf = $self->process_line($line[1]);
	return -1 unless $rf; #-- job is done
	
	my $changed;
	while(my ($key, $value) = each %$rf){
	    if($self->$key ne $value){
		$self->$key($value);
		$changed = 1;
	    }
	}
	return $changed;
    }
    else{ #-- blades are down
	return undef;
    }
}

sub desc{
    my $self = shift;
    if($self->debug_job){
	return $self->job_id.' '.$self->user."\@".$self->exec_host;
    }
    
    return $self->status.' '.$self->user
	.($self->exec_host ? "\@".$self->exec_host : '');
    #. ' ('.$self->job_id.')';
}

sub pretty{
    my $self = shift;
    if($self->debug_job){
	return $self->job_id.' '.$self->user."\@".$self->exec_host;
    }    
    return "Job ".$self->job_id." (".$self->status." as ".$self->user."\@".$self->queue
	. ", ".($self->exec_host ? "on ".$self->exec_host." " : ''). ' from '.$self->from_host
	. " on ".$self->submit_time.")";
}

1;

=head1 TITLE

CSP::JOB

=head1 SYNOPSIS

written later.

=head1 FUNCTIONS 

=over 4

=item new ( PARAMS )

Create a new object.  Expects, at least, a job_id.  It will run a bjobs command to get the rest of the information if no other params are set.  If they are, uses those values and makes no system call.  It is important that you fill all fields if you are initializing by params

=item new_from_line ( LINE )

If you ran a bjobs command yourself (like bjobs -u all -a) and want to create the CSP jobs from there, you need only pass in the output from bjobs to create a new object.

=item process_line ( LINE )

Returns a hashref of param => value based on the LINE, which is the expected output from a bjobs command.  Used by new_from_line

=item job_id(), user(), status(), queue(), from_host(), exec_host(), submit_time()

The accessors that provide an interface to all information about an LSF job. This is the object interface to the information returned by bjobs

=item debug_job

true if we think this job_id indicates someone is debugging the confirm pse themselves, thus no blade information will be known.

=item refresh()

Reinit in case things have changed.

=item desc

a short textual description

=item pretty

a long textual description

=back

=cut
