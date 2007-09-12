package CSP;

use strict;
use warnings;

use GSCApp;

use Path::Class qw(dir file);
use Sys::Hostname qw(hostname);
use Carp;
use IO::Handle;
use IO::File;
use Time::HiRes;
use IPC::Open2 qw(open2);
use Date::Calc;

use CSP::PSE;
use CSP::Job;


=head1 NAME

CSP - Confirm Scheduled PSE utility functions and methods

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use CSP;

    ...

=head1 EXPORT

None.

=head1 METHODS

=head2 new

put stuff here...

=cut

our $PROCESS_TO_FILE = "/gsc/scripts/share/CSP/process_to.list";

# I've gone back a forth on whether this module ought
# to have an object or class interface.  For now I've
# settled on class.  -thepler
sub new {
    die "not allowed to create a csp object, Todd says";
    my $class = shift;
    my %p = @_;
    my $self = bless {}, $class;
    return $self;
}

=head2 find_scheduled_pses

find_scheduled_pses(constraint => $constraint,
                    inputs     => \@inputs)

A generalized method to run a direct SQL query for scheduled
PSEs with no job_id, constrained by a given column and inputs.
The constraints should be qualified by a table alias, so you
should probably look at the code of the method to use it.

This method was mainly created as a way to write this code once
but handle two ways of specifying which PSEs to get:  either by
using specific pse_ids, or by specifying ps_ids.  There are
probably better ways to do it than this quick and dirty
implementation.

=cut

sub find_scheduled_pses {
    my %params=@_;

    my $constraining_column=$params{constraint};
    my @inputs=@{$params{inputs}};
    
    return unless(@inputs);
    
    my $placeholder_string='('.join(', ', ('?') x @inputs ).')';
    my $find_pses_query=qq(select pse.pse_id, pse.ps_ps_id, ps.pro_process_to
                           from process_step_executions pse
                           join process_steps ps on ps.ps_id = pse.ps_ps_id
                           left outer join pse_job pj on pj.pse_id = pse.pse_id
                           where pse.psesta_pse_status = 'scheduled'
                           and pj.job_id IS NULL
                           and $constraining_column IN $placeholder_string);
    my $pse_id_ref=App::DB->dbh->selectall_arrayref($find_pses_query,
                                                    undef,
                                                    @inputs);
    return @$pse_id_ref;
}


=head2 sub blades_down()

Indicates whether the blades are "still" down.  This is an optimistic test: if there are no reported problems, it will not check to verify that nothing bad has happened.  Once indicated that the blades are down, it will continue to return that the blades are down until 5 minutes has expired, at which point it will recheck the blades and either wait another 5 minutes are return false (ie. the blades are Not down).  

Parameters: 
 force : if set to true, force will always check the blade center and so you will have verification whether they are down *right now*.
 cmd : if a command is provided, it will use that command instead of the default 'bhosts' command.  Note that this provides a more accurate blades-down measure because it is no longer an optimistic test.  You will still receive a true scalar value if the blades are down, and it will still put a 5 minute wait on the last failure time before attempting to access them again, *but* if it is suggested the blades are not down, it will run the provided command and use that as the test to determine down-ness.  If the blades are down, as noted, it will return a true scalar value.  If the blades are not down, it will return an array-ref of the values returned by your command.  No false value is possible.

=cut

my $BDOWN;
sub blades_down{
#params 
#  force => 1 : check the blades no matter what
#  cmd => 1 : run this as the command if you're going to be checking the blades (or if )

    my $class = shift;
    my %params = @_;

    if(!$params{force} && defined $BDOWN && $BDOWN){
	#--- we think they are down
	my $now = time;
	if($params{force} || ($now - $BDOWN > 300)){ #-- check again
	    $BDOWN = 0;
	}
	else{
	    return $BDOWN;
	}
    }
    elsif(!$params{force} && !$params{cmd}){ 
	#--- user was just checking to see if there was a known issue
	return 0;
    }

    my $cmd = $params{cmd} || 'bhosts';
    
    #--- check just a generic timer
    my $timein = Time::HiRes::time();
    my @values = `$cmd`;
    my $timeout = Time::HiRes::time();
    if($timeout - $timein > 1000){
	$BDOWN = time;
	return $BDOWN;
    }
    else{
	$BDOWN = 0;
	return ($params{cmd} ? \@values : 0);
    }
}

=head2 sub run_blade_cmd ( cmd )

Runs the command on the blade center provided it is not down.  Automatically uses blades_down().  It *is* ambiguous if you receive () in return, because it may mean the blades are down, or that you have no results.  A subsequent call to blades_down() will clear it up if it is significant.

=cut

sub run_blade_cmd{
    my $class = shift;
    my $cmd = shift;

    my $result = $class->blades_down(cmd => $cmd);
    return () unless ref $result;
    return @$result;
}

=head2 find_jobs 

a function to find CSP::PSE objects and their jobs.  The parameters may be any constraint hash (see find_csp_pses), or 'csp_pse' => arrayref if you have already found the objects you want to find jobs for.  If there is no csp_pse parameter, it will call find_csp_pses with the parmaeters, thus the reason the constriant hash works just find.

=cut

sub find_jobs{
    my $class = shift;
    my %params = @_;

    my @csp_pses = (exists $params{'csp_pse'} 
		    ? @{$params{'csp_pse'}} 
		    : $class->find_csp_pses(%params));
    
    return () unless @csp_pses; #-- no csps found

    my @output;

    unless(@output = CSP->run_blade_cmd("bjobs -a -u all 2>&1")){
	return @csp_pses;
    }
    
    
    my %bladestats;
    for my $i ( 1 .. $#output ) { #-- '1' to skip header
	next unless $output[$i];
	my ($jobid) = $output[$i] =~ /^([^\s]+)/;
	next unless $jobid;
	$bladestats{$jobid} = $output[$i];
    }
    
    
    foreach (@csp_pses){
	next unless $_->job_id;
	if(exists $bladestats{$_->job_id}){
	    return unless $_->process_job_line($bladestats{$_->job_id});
	}
	else{
	    $_->no_job_found(1);
	}
    }
    return @csp_pses;
}

=head2 find_csp_pses

This is a function to find the CSP::PSE objects for currently scheduled/confirming/failed pses from the database.  Because you may like a lot of different information for these, we have this function and the objects, which do other cool things.  

The parameters is a hash to additional constraints.  The default is 
 pse_status => ['scheduled', 'confirm', 'confirming']

Which does what you expect.  You can put any constraints on the process_steps or process_step_executions table.  The '=>' is autoresolved to an '=' or an 'in' clause.

=cut

sub find_csp_pses{
    my $class = shift;
    my %params = @_;
    
    my %constraints;

    #--- this is a less hardcore but still hokey version of find_scheduled_pses
    #    that will return created CSP::PSE objects 
    
    if(exists $params{psesta_pse_status}){
	$constraints{'pse.psesta_pse_status'} = delete $params{psesta_pse_status};
    }
    else{
	$constraints{'pse.psesta_pse_status'} = ['scheduled', 'confirm', 'confirming'];
    }
    
    my @possible_properties;
    foreach ('PROCESS_STEP_EXECUTIONS', 'PROCESS_STEPS'){
	push @possible_properties, map {lc($_)} App::DB::Table->get($_)->column_names;
    }
    foreach (@possible_properties){
	if(exists $params{$_}){
	    $constraints{$_} = $params{$_};
	}
    }
    

    my $query = qq{select /*+ordered */
		       ps.pro_process_to, pse.pse_id, unix_login,pse.psesta_pse_status, 
		       pse.pr_pse_result, to_char(pse.date_scheduled, 'dd-mon-yyyy hh:mi'),  
		       pj.job_id, ps.ps_id
		       from process_step_executions pse
		       join process_steps ps on pse.ps_ps_id = ps.ps_id
		       left outer join pse_job pj on pse.pse_id = pj.pse_id 
		       left outer join 
		       ( select unix_login, ei_id from employee_infos ei 
			 join gsc_users gu on gu_gu_id = gu_id
			 where ei.us_user_status = 'active' and gu.us_user_status = 'active') emp
			 on emp.ei_id = pse.ei_ei_id
			 where };
    my @cst_strings;
    while(my ($column, $values) = each %constraints){
	if(ref $values){
	    if(@$values > 1){
		push @cst_strings, "$column in ('".join("','", @$values)."')";
	    }
	    else{
		push @cst_strings, "$column = '".$values->[0]."'";
	    }
	}
	else{
	    push @cst_strings, "$column = '".$values."'";
	}
    }
    $query .= join(" AND ", @cst_strings);

    my $sth = App::DB->dbh->prepare($query) || die;
    $sth->execute() || die;
    
    my @obj;
    while (my @row = $sth->fetchrow_array){
	my $obj = CSP::PSE->new_nocheck(process => $row[0],
					pse_id => $row[1],
					user => $row[2],
					pse_status => $row[3],
					pse_result => $row[4],
					date_scheduled => $row[5],
					ps_id => $row[7],
					job_id => $row[6]);
	push @obj, $obj;
    }
    
    return @obj;
}

=head2 choose_pses

@pse_ids=CSP::choose_pses(limit => $job_limit,
                          infos => \@pse_infos);

This method chooses which PSEs to schedule when there are more scheduled
PSEs than the current limit allowed in PBS.  It takes in limit parameter,
representing the total number of jobs that need to be scheduled; and an
arrayref of pse informations, consisting of scheduled pse_ids and the
queue that they need to be sent to.

An optional parameter is a hashref detailing how much each queue has
in it; if this hash is not specified, the method will build it itself.

The point here is to try to keep one queue from getting all the pses sent
to it.  This could happen if one queue runs particualarly slower than
others; a straight-forward take-oldest method would continually
select pses from the same slow queue, backing it up even more, while
faster queues would eventually empty, but not get filled up.  This
would lead to a sub-optimal use of resources.

(It would not be a problem if PBS could accept an infinite number of
jobs.)

The current logic of this method tries to ensure that each queue having
jobs ends up with approximately the same amount scheduled.  This means
that emptier queues will get more jobs sent to them.  The theory behind
this is that emptier queues are faster queues.

=cut

sub choose_pses {
    my %params=@_;
    my $job_limit=$params{limit};
    return unless($job_limit);
    my @infos=@{$params{infos}};
    
    # Set up hash to hold count of how many pses are currently
    # assigned to each queue.  We allow you to pass this in,
    # mostly for testing
    my %queue_count;
    if(exists $params{queue_count}) {
        %queue_count=%{$params{queue_count}};
    }

    # First, separate the PSEs by queue and ps_id
    my %pses;
    my %queue_for_ps_id=();
    foreach my $info (sort {$a->[0] <=> $b->[0]} @infos) {
        my ($pse_id, $ps_id)=@$info;

        unless(exists $queue_for_ps_id{$ps_id}) {
            my $ps=GSC::ProcessStep->get($ps_id);
            my $queue=$ps->pbs_queue || 'database';
            $queue.='@qblade' unless($queue=~/\@qblade/);
            $queue_for_ps_id{$ps_id}=$queue;
            $queue_count{$queue}||=0;
        }
        
        my $queue=$queue_for_ps_id{$ps_id};
        push @{$pses{$queue}{$ps_id}}, $pse_id;
    }

    # Find out how many are in each queue we're looking at right now
    my $currently_in=0;
    foreach my $queue (keys %queue_count) {
        unless($queue_count{$queue}) {
            # This queue has not been set by being passed in
            if(my @jobs=`qstat $queue`) {
                $queue_count{$queue}=@jobs-2;
            }
        }
        $currently_in+=$queue_count{$queue};
    }
    
    # We want each of the competing queues to end up with the same number of jobs scheduled
    # This is a guesstimate, but it should on average give priority to faster queues,
    # which should result in a better use of processing resources
    my $target_number=sprintf("%.0f", ($currently_in+$job_limit)/(keys %queue_count))+1;
    
    # Come up with an order for PS_IDs to add to each queue, and save it
    # This way, we can spread the scheduling amongst each job that runs on a queue
    my %queue_ps_order=();
    #foreach my $queue (keys %pses) {
    #    my $ps_hash=$queue_for_ps_id{$queue};
    #    $queue_ps_order{$queue}=[keys %$ps_hash];
    #}
    foreach my $ps_id (keys %queue_for_ps_id) {
        my $queue=$queue_for_ps_id{$ps_id};
        push @{$queue_ps_order{$queue}}, $ps_id;
    }

    # Get the PSE_IDs we want
    my @pse_ids;
    #my $time=time;
    #my $count=0;
    while(@pse_ids<$job_limit) {
        foreach my $queue (keys %queue_ps_order) {
            #$count++;
            #print "Doing iteration $count at ".localtime()."\n";

            # If this queue is over the target, that probably means it's slow
            # We don't want to schedule more things into it until it clears up a bit
            next if($queue_count{$queue}>=$target_number);
            
            # Take the next ps_id in the order for this queue,
            # and take it's first pse_id, and schedule it
            my $next_ps_id=shift @{$queue_ps_order{$queue}};
            push @pse_ids, shift @{$pses{$queue}{$next_ps_id}};
            $queue_count{$queue}++;

            # Make sure there are more PSE_IDS for this ps_id if we're going to use it again
            if(@{$pses{$queue}{$next_ps_id}}>0) {
                push @{$queue_ps_order{$queue}}, $next_ps_id;
            }
            
            # Make sure that we don't use this queue again if there are no PSEs from it
            # to schedule; checking the queue_ps_order entry should suffice for that
            unless(@{$queue_ps_order{$queue}}>0) {
                delete $queue_ps_order{$queue};

                # If this queue didn't use all the jobs we allocated to it,
                # we better up the job target so that the other queues can pick
                # up the slack
                if($queue_count{$queue}<$target_number) {
                    my $unused_jobs=$target_number-$queue_count{$queue};
                    # Up the target by an equal amount for each remaining queues
                    my $other_queues=scalar(keys %queue_ps_order) || 1;
                    $target_number+=int($unused_jobs/$other_queues)+1;
                }
            }


            # Quit out of this loop if we've got enough; the main loop will then also quit
            last unless(@pse_ids<$job_limit);
        }
    }
    #print "$count iterations took ".(time-$time)." seconds\n";

    return @pse_ids;
}

=head2 log_fh

class method
class wide logging file handle
put stuff here...

=cut

my $log_fh;

sub log_fh {
    my $class = shift;
    $log_fh = shift if (@_);
    return $log_fh;
}

# central logging function
sub log_this {
    my ( $type, $text ) = @_;
    my $msg = sprintf(
        "%-9s %s\t%s\n",
        uc($type) . ':',
        App::Time->now,
        $text,
    );
    $log_fh->print($msg) if $log_fh;
}

sub log_callback {
    my $msg_obj = shift;

    # skip copious messages from App::DB classes/objects
    return if $msg_obj->{owner_class} =~ /^App::DB::/;

    log_this( $msg_obj->type, $msg_obj->text );
}

sub sig_handler {
    my ( $type, $text ) = @_;

    {
        # try to make Carp not truncate messages
        local $Carp::MaxArgLen  = 0;
        local $Carp::MaxArgNums = 0;
        local $Carp::CarpLevel  = 2;

        $text = Carp::longmess($text);
    }

    log_this( $type, $text );
}

sub setup_logging_callbacks {

    # set up callbacks
    App::MsgLogger->message_callback( 'status',  \&log_callback );
    App::MsgLogger->message_callback( 'warning', \&log_callback );
    App::MsgLogger->message_callback( 'error',   \&log_callback );
#    App::MsgLogger->message_callback( 'debug',   \&log_callback );

    # catch die and warn messages
    $SIG{__DIE__}  = sub { sig_handler( 'die',  $_[0] ) };
    $SIG{__WARN__} = sub { sig_handler( 'warn', $_[0] ) };
}

=head2 setup_confirm_scheduled_pse_cron_command_line_options

put stuff here...

=cut

sub setup_confirm_scheduled_pse_cron_command_line_options {
    my %arg;

    App::Getopt->command_line_options(
        'process' => {
            option => '--process=STRING',
            argument => '=s',
            msg => 'the process type (process_to) to find and confirm',
            action => \$arg{process_to},
        },
        'queue' => {
            option => '--queue=STRING',
            argument => '=s',
            msg => 'the PBS queue to use',
            action => \$arg{queue},
        },
        'ignore-locks' => {
            msg => 'ignore filesystem and database locks and initiate jobs anyway',
            action => \$arg{ignore_locks},
        },
    );

    return \%arg;
}

=head2 log_dir

put stuff here...

=cut


sub log_dir{
    if($^O eq 'MSWin32'){
        return dir('//winsvr/var/log/confirm_scheduled_pse');
    }
    return dir('/gsc/var/log/confirm_scheduled_pse');
}
#--- do this fast:
{ 

    foreach my $subdir(qw(jobs done fail assigned_fail prev_fail cron command_log output)){
        no strict;
        my $func_name = 'CSP::'.$subdir.'_dir';

        *$func_name = sub{ 
            my $class = shift; 
            my $base = $class->log_dir;
            return $base->subdir($subdir);
        };
    }
}

# a global lock means that we should not try to connect
# to the database at all
sub global_locked {
    my %rv = GSCApp::QLock->status(queue => 'csp');
    my ($v) = values %rv;
    ($v) = values %$v;
    return $v;
}

# a process lock means we can connect to the database
# and figure out what process step we are, but we
# could still be locked
sub process_locked {
    my ( $class, $process ) = @_;

    croak 'must pass a process to process_locked()' unless $process;
    $process =~ s/\s+/_/g;
    require PP;
    my $config = PP->config( $process ) or die "no config for $process";
    my $queue = $config->{queue};

    # if we have no queue, then it's probably not a pp_type of lsf
    # probably it's fork, which means it can't be locked
    return if ( !defined $queue );

    $queue = 'seqmgr' if ($queue eq 'long');        # HACK
    $queue = 'seqmgr' if ($queue eq 'seqmgr-long'); # HACK
    $queue = 'seqmgr' if ($queue eq 'dumpread');    # HACK
    my %rv = GSCApp::QLock->status(queue => 'csp:' . $queue);
    my ($v) = values %rv;
    ($v) = values %$v;
    return $v;
}

=head2 confirm_scheduled_pse_cron

put stuff here...

=cut

# higher priority steps get dispatched first
my %csp_priority = (

    # high priority touchscreen steps
    'assign custom sequencing primers to dna' => 10,
    'claim dna'                               => 10,
    'define alternate chemistry amplicon'     => 10,                   
    'create dna container'                    => 10,
    'create pcr product'                      => 10,
    'create sequenced dna'                    => 10,
    'archive transfer'                        => 10,
    'deactivate project'                      => 10,
    'digest dna'                              => 10,
    'dilute ipr product'                      => 10,
    'extract fraction'                        => 10,
    'load gel'                                => 10,
    'new primers'                             => 10,
    'pick'                                    => 10,
    'rearray dna'                             => 10,
    'sequence'                                => 10,
    'set up beckman block'                    => 10,
    'normalize dna'                           => 10,
    'validate amplicon'                       => 10,
    'validate primer tube'                    => 10,
    # middle priority stuff
    'analyze amplicon failure' => 5,
    # lower priority steps
    'analyze 454 output'                      => 1,
    'analyze sequenced dna'                   => 2,
    'analyze digested dna'                    => 1,
    'etl reads from oltp to olap'             => 1,
    'mp read analysis'                        => 1,
    'update mp assembly'                      => 1,
    'add read to mp assembly'                 => 1,
    'import external reads'                   => 1,
    'gather submission results'               => 1,
    'prepare read submission'                 => 1,
    'submit reads'                            => 1,
    'configure image analysis and base call'  => 1,
    'make default offsets'                    => 1,
    'configure alignment'                     => 1,
    'import sequence annotation'              => 2,

#    these were given their own cron to get around the
#    problem of running as the lims user instead of seqmgr
#    'analyze traces'                          => 2,
#    'dump reads to filesystem'                => 1,
#    'transfer tagged 454 run'                 => 1,
#    'submit finished clone to qa'             => 1,
#    'mkcs'                                    => 1,
#    'shotgun done'                            => 1,
#    'autofinish'                              => 1,
#    'assemble 454 regions'                    => 1,
);

sub csp_priority { %csp_priority }

our %WAIT_ON_RESOURCE;
# entry point for the confirm_schedule_pse_cron script
sub confirm_scheduled_pse_cron {
    my ( $class, $arg ) = @_;

    my @pse_ids      = @{ $arg->{pse_ids} };
    my $ignore_locks = $arg->{ignore_locks};
    my $process_to   = $arg->{process_to};
    my $queue        = $arg->{queue};
#    my $MAX_JOBS     = 2500;

    my $_process_to_ = $process_to;
    $_process_to_ =~ s/\s+/_/g if ($_process_to_);
    #########################
    # set up message logging
    #########################

    # check for the log directory
    my $cron_dir = $class->cron_dir;
    die "log directory ".$cron_dir." not found" if ( !-d $cron_dir );

    # make up a log file name
    # one log file per day
    my ($today) = split(/ /, App::Time->now);
    if ($_process_to_) {
        $today .= "_$_process_to_";
    }
    my $logfile = $cron_dir->file($today . '.log');

    # open file
    umask 0002;
    my $log_fh = $logfile->open('>>') or die "open $logfile failed: $!";
    $log_fh->autoflush(1);
    $class->log_fh($log_fh);
    $class->setup_logging_callbacks;


    App::Object->status_message(
        App::Name->prog_name . ' started on ' . hostname()
        . " as " . getpwuid($<) . " with pid $$"
    );

    # Don't even start running if we're locked
    # (But at least write to the log file)
    if ( $class->global_locked and !$ignore_locks ) {
        App::MsgLogger->warning_message('Locked: exiting');
        exit 0;
    }

    # make sure 1 and only 1 process is running at a time
    my $resource_id = 'confirm_scheduled_pse_cron';
    if ($_process_to_) {
        $resource_id .= "_$_process_to_";
    }
    App::Object->status_message("$$ looking for db lock for $resource_id");
    my $cspc_lock = App::Lock->create(
        mechanism   => 'DB_Table',
        resource_id => $resource_id,
        block       => 0,
    );
    if (! $cspc_lock and ! $ignore_locks) {
        App::Object->status_message("$$ did not get lock, quitting");
        exit 0;
    }

    ###################
    # do the real work
    ###################

    my %csp_priority = $class->csp_priority;
    my @process_to   =
        grep { !$class->process_locked($_) }
        keys %csp_priority;

    my @pse_infos=();
    if (@pse_ids) {
        # Get scheduled PSE IDs from pse_ids passed on command line
        # There is a chance this could break if you passed in more than 1000 PSE IDs
        @pse_infos=CSP::find_scheduled_pses(constraint => 'pse.pse_id',
                                            inputs     => \@pse_ids);

    } else {
        # find PSEs from the database

        # override default with command-line --process flag
        @process_to = ($process_to) if $process_to;

        my $process_to_string = join(', ', map { "'$_'" } @process_to);

        # get the process step objects
        GSC::ProcessStep->status_message("Looking for active process steps with a process_to in ($process_to_string)");
        my @ps = GSC::ProcessStep->get(
                        process_to          => \@process_to,
                        process_step_status => 'active',
        ) or do {
            GSC::ProcessStep->warning_message("did not find any active process steps with a process_to of $process_to_string");
            $cspc_lock->delete if $cspc_lock;
            exit 0;
        };

        @pse_infos=CSP::find_scheduled_pses(constraint => 'pse.ps_ps_id',
                                            inputs     => [map {$_->id} @ps]);
        
    }

    GSC::PSE->status_message("found " . scalar(@pse_infos) . " PSEs to confirm");


#   sort by priority and pse_id
    @pse_ids =
        map  { $_->[0] }
        sort {
            my $x = $csp_priority{ $b->[2] } || 0;
            my $y = $csp_priority{ $a->[2] } || 0;
            ( $x <=> $y ) || ( $a->[0] <=> $b->[0] );
        } @pse_infos;

    #####################################################################

    my $use_dbh = App::DB->dbh->clone();

    for my $pse_id (@pse_ids) {
        # see if there is a global lock
        if ( $class->global_locked and !$ignore_locks ) {
            App::MsgLogger->warning_message('Locked: exiting');
            last;
        }

        my $pse=GSC::PSE->get($pse_id) or next;
	
	if(my @resources = $pse->resource_needed) {
	  my $is_wait = 0;
	  foreach my $resource (@resources) {
	    if($WAIT_ON_RESOURCE{$resource}) {
	      $is_wait = 1;
	      last;
	    }
	  }
	  next if($is_wait);
	  foreach my $resource (@resources) {
	    $WAIT_ON_RESOURCE{$resource} = 1;
	  }
	}
	
        my $process_to = $pse->get_ps->process_to;

        # see if there is a lock for this process step
        if ( $class->process_locked($process_to) and !$ignore_locks ) {
            $pse->status_message("$process_to is locked, skipping $pse_id");
            next;
        }

        $pse->status_message("checking for a pse job for $pse_id ($process_to)");
        my $pj = GSC::PSEJob->get(pse_id => $pse_id);
        if ($pj) {
            my $job_id = $pj->job_id;
            $pse->status_message("pse job found for $pse_id ($process_to), job_id $job_id skipping");
            next;
        }

        my $msg = "confirm scheduling for $pse_id ($process_to)";
        $pse->status_message("no pse job found, calling $msg");

        # hack queue override
        $pse->{_queue} = $queue if $queue;

        # kick off the job
        my $rv = $pse->confirm_scheduling(dbh=>$use_dbh);

        if ($rv) {
            $pse->status_message("successful $msg");
        }
        else {
            $pse->error_message("failed to $msg");
        }
    }

    $cspc_lock->delete if $cspc_lock;
    exit 0;
}

sub group_by (@) {

    my @code;
    while ( ref $_[0] && ref $_[0] eq 'CODE' ) {
        push @code, shift;
    }
    if ( @code == 0 ) {
        croak 'group_by takes at least one code ref';
    }

    my $ret = {};

ALL:
    for (@_) {
        my @ans;
        for my $c (@code) {
            my $ans = &{$c}();
            next ALL if ( !defined $ans );
            push @ans, $ans;
        }

        my $last = pop @ans;
        my $r = $ret;
        for my $a (@ans) {
            $r->{$a} ||= {};
            $r = $r->{$a};
        }

        $r->{$last} ||= [];
        push @{ $r->{$last} }, $_;
    }

    return $ret;
}

sub csp_status {
    my ($class, $fh) = @_;
    $fh ||= 'STDOUT';

    $fh->print("\n");
    $fh->print("Global Lock: " . $class->global_locked . "\n\n");

    my %csp_priority = $class->csp_priority;
    for my $ps ( sort keys %csp_priority ) {
        $fh->printf(
            "%-40s locked: %s\n",
            $ps, $class->process_locked($ps)
        );
    }

    # get database status
    my @process_to = keys %csp_priority;
    my $process_to_string = join(', ', map { "'$_'" } @process_to);

#            (case when (pse.psesta_pse_status = 'scheduled' and pj.job_id is not null) then 'scheduled+job_id' else pse.psesta_pse_status end) status
    my $sql = qq{
        select
            ps.pro_process_to process_to,
            pse.psesta_pse_status status,
            pse.pr_pse_result result,
            pse.pse_id pse_id,
            pse.date_scheduled date_scheduled,
            pj.job_id job_id
        from process_steps ps
        join process_step_executions pse on ps.ps_id = pse.ps_ps_id
            and pse.psesta_pse_status
                in ('scheduled', 'wait', 'confirm', 'confirming')
        left outer join pse_job pj on pj.pse_id = pse.pse_id
        where ps.pro_process_to in ( $process_to_string )
    };

    my $dbh = App::DB->dbh;
    my $sth = $dbh->prepare($sql) or die;
    $sth->execute or die;
    my $ar = [];
    @$ar = @{ $sth->fetchall_arrayref( {} ) } or die;

    # get lsf status
    my @lsf_jobs = `bjobs -a -u all 2>&1`;
    shift @lsf_jobs;    # header
    my %lsf_status;
    for my $line (@lsf_jobs) {
        my @stats = split( /\s+/, $line );
        my $job_id = $stats[0];
        my $stat  = $stats[2];
        $lsf_status{$job_id} = $stat;
    }

    # join them (it's kinda like a join :)
    for my $pse (@$ar) {
        $pse->{LSF_STAT}    = '-';
        $pse->{HAS_JOB_ID}  = 'no';
        $pse->{HAS_LSF_JOB} = 'no';
        if ( $pse->{JOB_ID} ) {
            $pse->{HAS_JOB_ID} = 'yes';
            if ( $lsf_status{ $pse->{JOB_ID} } ) {
                $pse->{LSF_STAT}    = $lsf_status{ $pse->{JOB_ID} };
                $pse->{HAS_LSF_JOB} = 'yes';
            }
        }
    }

    my $grp = group_by
        sub { $_->{PROCESS_TO} },
        sub { $_->{STATUS} },
        @$ar
    ;

#    my $grp = group_by { $_->{PROCESS_TO} } @$ar;

    return $ar;
}

sub csp_straggler_alert {
    my $class = shift;

    my %csp_priority = $class->csp_priority;
    my @process_to = keys %csp_priority;
    my $process_to_string = join(', ', map { "'$_'" } @process_to);
    my $days_ago =
        sprintf("to_date('%s', 'YYYY-MM-DD')",
            App::Time->add_date_delta_days(App::Time->now, -3)
        );

    my $sql = qq{
        select
            ps.pro_process_to,
            pse.date_scheduled,
            pse.pse_id
        from process_steps ps
        join process_step_executions pse on ps.ps_id = pse.ps_ps_id
            and pse.psesta_pse_status = 'confirm'
            and pse.pr_pse_result = 'failed'
            and pse.date_scheduled < $days_ago
        where ps.pro_process_to in ( $process_to_string )
        order by ps.pro_process_to, pse.date_scheduled, pse.pse_id
    };

    my ($rdfh, $wtfh);
    my $pid = open2($rdfh, $wtfh, 'sqlrun - 2>&1');
    $wtfh->print($sql);
    $wtfh->close;
    return $rdfh;

# The following should work, but there's a bug somewhere
#
#    my $out;
#    my $fh;
#    open($fh, ">", \$out);
#
#    App::DB::Report->generate(
#        sql   => $sql,
#        outfh => $fh,
#    );
#
#    $out;
}

=head2 setup_confirm_scheduled_pse_command_line_options

put stuff here...

=cut

sub setup_confirm_scheduled_pse_command_line_options {

    my %arg;

    App::Getopt->command_line_options(
        job => {
            option  => '--job',
            message =>
                'Create a pse_job record before setting up confirm (debug only!)',
            action => \$arg{is_to_make_job},
        },
        unscheduled => {
            option  => '--unscheduled',
            message =>
                "Allow confirmation of the PSE even though it is not scheduled.  Used for developer manual reprocessing.  Creates a pse_job record if necessary.",
            action => \$arg{confirm_unscheduled_pse},
        },
        'tee-stdout' => {
            option  => '--tee-stdout',
            message =>
                'Any message going to the log also go to STDOUT',
            action => \$arg{tee_stdout},
        },
        'ignore-locks' => {
            msg => 'ignore filesystem and database locks and try to confirm the PSE anyway',
            action => \$arg{ignore_locks},
        },
    );

    return \%arg;
}

=head2 log_file_name

put stuff here...

=cut

# perhaps this should be a method on GSC::PSE ???
# maybe called "make_up_new_log_file_name" ???       -thepler
sub log_file_name {
    my ( $class, $pse ) = @_;

    croak 'must pass a PSE' if ( !$pse );

    # make up a log file name
    my $pse_id = $pse->pse_id;
    my $pt     = $pse->get_process_step->process_to;
    $pt =~ s/\s+/_/g;
    my $now = App::Time->now;
    $now =~ s/\s+/_/g;
    return join( '.', $pse_id, $pt, $now, 'log' );
}


=head2 confirm_scheduled_pse

put stuff here...

=cut

sub confirm_scheduled_pse {

    my ( $class, $arg ) = @_;

    # Get parameters. 
    my $pse_id = $arg->{pse_id};
    my @params = @{ $arg->{params} };
    die 'no pse to confirm' unless $pse_id;
    my $is_to_make_job          = $arg->{is_to_make_job};
    my $confirm_unscheduled_pse = $arg->{confirm_unscheduled_pse};
    my $tee_stdout              = $arg->{tee_stdout};
    my $ignore_locks            = $arg->{ignore_locks};

    # check for global lock
    if ( !$ignore_locks ) {
        while ( $class->global_locked ) {
            sleep 5 * 60;
        }
    }

    # note this so we can track the elapsed time
    my $start_time = Time::HiRes::time();

    ####################################################
    # We need database access to even make the log file,
    # so this must happen first.
    ####################################################

    # ensure we have a database connection
    App::DB->dbh or die 'cannot connect to database';

    # get the pse object
    GSC::PSE->class;
    my $pse = GSC::PSE->get(pse_id => $pse_id)
        or die "pse $pse_id does not exist";
    my $process_to = $pse->get_ps->process_to;

    # check for a process step lock
    if ( !$ignore_locks and $class->process_locked($process_to) ) {

        # delete the pse job if we have one
        my $pj = GSC::PSEJob->get( pse_id => $pse_id );
        if ($pj) {
            $pj->delete            or die 'failed to delete pse job';
            App::DB->sync_database or die 'sync_database failed';
            App::DB->commit        or die 'commit failed';
        }

        exit;
    }

    #########################
    # set up message logging
    #########################
    my $jobs_dir = $class->jobs_dir(); 
    my $done_dir = $class->done_dir(); 
    my $fail_dir = $class->fail_dir(); 
    my $prev_fail_dir = $class->prev_fail_dir(); 

    for my $dir ( $jobs_dir, $done_dir, $fail_dir, $prev_fail_dir ) {
        die "log directory $dir not found" if ( !-d $dir );
    }

    $class->deal_with_previous_failures($pse_id);

    # make up a log file name
    my $_process_to_ = $process_to;
    $_process_to_ =~ s/\s+/_/g;
    my $now = App::Time->now;
    my ($today) = split( / /, $now );
    $now =~ s/\s+/_/g;
    if ( $^O eq 'MSWin32' ) {
        $now =~ tr/:/_/;    # cannot put ":" in filenames in windows
    }
    my $logfile = $jobs_dir->file(
        join( '.', $pse_id, $_process_to_, $now, 'log' )
    );
    die "log file $logfile already exists" if -e $logfile;

    # open log file
    my $log_fh = IO::File->new or die 'IO::File->new failed';
    if ($tee_stdout) {
        if ( $^O eq 'MSWin32' ) {
            die 'cannot tee-stdout on windows';
        }
        $log_fh->open("| tee $logfile")
            or die "failed to open $logfile: $!";
    }
    else {
        $log_fh->open("> $logfile")
            or die "failed to open $logfile: $!";
    }
    $log_fh->autoflush(1);
    $class->log_fh($log_fh);
    $class->setup_logging_callbacks;
#    chmod( 0666, $logfile );    # just try, it's ok if it fails
    chmod( 0666, $logfile ) or die "chmod $logfile failed: $!";

    # write dump-sql to the log when monitoring is turned-on
    # note that this is turned-on by default below
    App::DBI->sql_fh($class->log_fh);

    ######################################################
    # Initialize everything.
    # We die on early errors because we don't have enough
    # knowledge of a pse-job to try to delete it.
    ######################################################

    # the error message that will get emailed should something fail
    my @error_message;


    # This ensures that key modules related to the 
    # PSE are initialized at the beginnning of confirmation,
    # instead of "just-in-time".  This helps debugging, and 
    # ensures that compilation errors lead to an early failure.
    if ($pse->can("_pre_initialize_confirmation_modules")) {
        $pse->status_message("Pre-initializing related classes.  Disabling SQL dumping for this task only if it is on.");
        eval {
            $pse->_pre_initialize_confirmation_modules();
        };
        if ($@) {
            $pse->error_message("Error pre-initializing confirmation modules: $@");
            exit 1;
        }
        $pse->status_message("Related classes initialized");
    }


    # We always monitor the SQL for the log file, but not until
    # after the initialization is done, since that stuffs the log with uninteresting things.
    App::DBI->monitor_sql(1);

    ####################################
    # Validate the PSE for confirmation
    ####################################

    my $hostname = hostname();
    chomp $hostname;
    $pse->status_message("hostname: $hostname");
    $pse->status_message("pid: $$");
    my $lsf_job_id = $ENV{LSB_JOBID};
    if ($lsf_job_id) {
        $pse->status_message("LSF job id: $lsf_job_id");
    }
    else {
        $pse->status_message('I do not think I am running via LSF');
    }

    #- pse must have a scheduled status
    if ( $pse->pse_status eq 'scheduled' ) {
        $pse->status_message('status is scheduled');
    }
    elsif ($confirm_unscheduled_pse) {
        # should we actually set status to scheduled here?
        $pse->status_message('running with confirm_unscheduled_pse');
    }
    else {
        die "status of pse_id is '" . $pse->pse_status . "', not 'scheduled'";
    }

    #- pse must have a PSEJob to indicate that and where it is running.
    my $psejob = GSC::PSEJob->get(pse_id => $pse_id);
    if ($psejob) {
        if ($is_to_make_job) {
            die "A PSE job already exists for this step!"
        }
    }
    else {
        if ($is_to_make_job or $confirm_unscheduled_pse) {
            my $jobid = ($^O eq 'MSWin32' ? 'localhost' : getpwuid($<))
                ."@".$hostname . ".". $$;
            
            $pse->status_message("Generating a to make job.");
            
            unless (
                $psejob = GSC::PSEJob->create(
                    pse_id=>$pse->id, 
                    job_id=>$jobid
                )
            ) {
                die "failed to create pse job for " . $pse->id . "(job id $jobid)";
            }
            App::DB->sync_database
                or die "sync_database failed on inserting PSE Job link";
            
            $pse->status_message("Inserted job id $jobid before confirming.");
        }
        else {
            die 'must have a PSE job';
        }
    }

    my $pse_job_id = $psejob->job_id;
    $pse->status_message("PSE job id: $pse_job_id");

    ####################
    #
    # Everything up to this point calls 'die' if something is wrong.
    # If anything goes wrong after this point, 2 things must be done:
    #    - the pse status/result must be set to confirm/failed
    #    - the pse job must be deleted
    #
    ####################


    ############################
    # attempt to confim the pse
    ############################

    my $rv = eval {
        
        # select for update
        $pse->status_message('doing select for update');
        $pse->unload;
        $pse = GSC::PSE->load(sql => qq{
            select * from process_step_executions
            where pse_id = $pse_id
            for update
        });
        $pse->status_message('finished select for update');

        if ( !$pse ) {

            # this would be weird
            die 'PSE went away when selecting for update';
        }
	
        if ( $pse->pse_status eq 'confirming' ) {

            # someone beat us to it
            die "status is 'confirming' after select for update, probably lost the race";
        }

        # set the status to confirming
        $pse->status_message("did not get 'confirming' pse_status");
        $pse->status_message("setting to 'confirming' myself");
        $pse->pse_status('confirming');
        App::DB->sync_database
            or die "sync_database failed on changing status to confirming";
        App::DB->commit
            or die "commit failed on changing status to confirming";
        $pse->status_message("successfully set status to 'confirming'");

        #-- set the status to inprogress (ie. confirmation complete)
        #   don't worry, we rollback if it fails.
        #   It is important to do this here, and *not* after the confirm:
        #      based on the actual processing in confirm_job, the
        #      status may be *reset* somewhere inline.  this is ok,
        #      and important to maintain.
        #   So, we set the status first, then confirm_job, then, if
        #   everything is ok, commit
        
        # we lock the database here so that no one else can
        # make changes (like, through scheduled_watcher)

        #LSF: To check for the require resource here.
	#     The reason do not do it before the sync is 
	#     because the is_resource_met might use 
	#     something that might not like the sync and commit.
	unless($pse->is_resource_met) {
	  $pse->status_message("require resource NOT met");
	  $pse->pse_status('scheduled');
	  $psejob->delete if($psejob);
          App::DB->sync_database
              or die "sync_database failed on changing status to scheduled";
          App::DB->commit
              or die "commit failed on changing status to scheduled";
          $pse->status_message("successfully set status to 'scheduled'");
	  die 'required resource NOT met';
	}
	
        $pse->pse_status('inprogress');

        # do not sync here - too much locking...
#        App::DB->sync_database
#            or die "Failed to sync the database on the pse for locking purposes";

        # detect a race
        # The above should catch race conditions, but this shouldn't
        # hurt, so double check

        $psejob = GSC::PSEJob->load( pse_id => $pse_id )
            or die 'PSE job went away, probably lost the race';

        if ( $psejob->job_id ne $pse_job_id ) {
            die "PSE job id changed from $pse_job_id to " . $psejob->job_id;
        }

        1;
    };

    unless($rv){
        my $error_message=$@;
        # Don't mail out for the 'required resource not met' error, since that is a common occurrence
        # and nobody needs to be bugged about it
        unless($error_message=~/^required resource NOT met/) {
            App::Mail->mail(
                            To      => 'autobulk',
                            Subject => "[CSP Warning] $pse_id $process_to",
                            Message => "PSE $pse_id could not be set to the appropate status.  \n\nThis usually happens\n\t(a) Harmlessly as another scheduled pse confirmer has control of the pse,\n\n\tor\n\n(b) As a result of a major database issue that you probably know about.  You may not have to worry about it.\n\n-The CSP Gnome\n\n\n$error_message",
                            );
          }
        exit 0;
    }


    $rv = eval{
        # call confirm_job

        $DB::single=1; # Debugger command, to put a breakpoint; ignored if debugger isn't used
        $pse->status_message("calling confirm_job on pse_id $pse_id ($process_to)");
        unless($pse->confirm_job(@params)){
            $pse->error_message("Failed to confirm the job: ".$pse->error_message);
            push @error_message, "Failed to confirm the job: ".$pse->error_message;
            return 0;
        }
        
        # call post_confirm

        if ($pse->pse_status eq 'wait') {
            $pse->status_message('skipping post_confirm() call because pse_status is wait');
        }
        else {
            $pse->status_message("calling post_confirm on pse_id $pse_id ($process_to)");
            unless($pse->post_confirm){
                $pse->error_message("Failed post_confirm: ".$pse->error_message);
                push @error_message, "Failed post_confirm job: ".$pse->error_message;
                return 0;
            }
        }

        # delete the pse job

        unless($psejob->delete){
            $pse->error_message("Failed to delete the psejob: ".$psejob->error_message);
            push @error_message, "Failed to delete the job: ".$psejob->error_message;
            return 0;
        }
        
        # sync and commit

        $pse->status_message("About to sync and commit");
        my $sync_start = Time::HiRes::time();

        unless (App::DB->sync_database && App::DB->commit) {
            App::DB->error_message("Failed to sync and commit : ".App::DB->error_message);
            push @error_message, "Failed to sync and commit the scheduled pse: ".App::DB->error_message;
            return 0;
        }

        my $sync_elapsed = Time::HiRes::time() - $sync_start;
        $pse->status_message(sprintf("elapsed sync and commit time: %.2f s", $sync_elapsed));

        1;
    };

    # the destination directory where the log file should be moved
    my $destdir;

    if ($rv) {
        $pse->status_message('confirm_job successful');
        $destdir = $done_dir->subdir($_process_to_)->subdir($today);
    }
    else {
        my $message=$@ || $error_message[-1];
        unless($pse->error_message) {
            $pse->error_message("confirm_job failed: $message");
        }
        $destdir = $fail_dir;
        
        push @error_message, "confirm_job() failed! $message";

        # get rid of all bad objects and context
        # this could involve one or more of:
        #
        #   reverse_all_changes
        #   fresh_start
        #   rollback
        #   disconnect
        #
        # we may need to experiment to see what works best

#        $pse->status_message('reverse_all_changes');
#        App::DB->reverse_all_changes;
        $pse->status_message('rollback');
        App::DB->rollback;
        $pse->status_message('disconnect');
        App::DB->disconnect;
        $pse->status_message('clear_cache');
        App::DB->clear_cache;

        # make sure we do not have any references
        # to any objects hanging around
        undef $pse;
        undef $psejob;

        # After clear_cache our logging callbacks will no longer
        # be in effect.  So we can 'die' from here on out, which
        # should end up in the stderr log

        # set pse to confirm/failed
        $pse = GSC::PSE->get( pse_id => $pse_id )
            or die "unable to re-get pse $pse_id";
        $pse->pse_status('confirm');
        $pse->pse_result('failed');

        # re-get the pse job, so it can be deleted
        unless(($psejob = GSC::PSEJob->get(pse_id => $pse_id)) && $psejob->delete){
            $pse->error_message("Failed to get or delete the pse job for a failed confirm");
            push @error_message, "Failed to get or delete the pse job for a failed confirm";
        }

        # final sync and commit
        # this commits confirm/failed
        # and always commits the delete of the pse_job

        unless (App::DB->sync_database && App::DB->commit) {
            $destdir = $fail_dir;
            App::DB->error_message('sync_database or commit failed for errored-out commit.  This is seriously bad!');
            push @error_message, 'sync_database or commit failed for errored-out commit.  This is seriously bad!';
        }
    }

    if ($lsf_job_id) {

        # log my own history
        App->status_message( join( '', `bhist -l $lsf_job_id 2>&1` ) );
    }

    # log elapsed time
    my $elapsed_time = Time::HiRes::time() - $start_time;
    App->status_message(sprintf("elapsed running time: %.2f s", $elapsed_time));

    # move the log file to the appropriate directory
    my $destfile = $destdir->file( $logfile->basename );
    $destdir->mkpath(0, 0777);
    if ( !-d $destdir ) {
        push @error_message, "failed to mkpath $destdir";
    }
    else {

        # Place the new log file.
        $class->log_fh->close;
        if ( !rename( $logfile, $destfile ) ) {
            push @error_message, "Failed to rename the logfile, too!";
        }
    }

    # send a notification upon failure
    if (! $rv || @error_message) {
        my $error_message = join("\n", @error_message);
        chomp $error_message;
        
        my $msg = qq{
            PSE failed to confirm: $pse_id ($process_to)
            
            Error message:
            $error_message
            
            Log file:
            $destfile
        };
        $msg =~ s/^[^\n\S]+//msg; # left-justify
        eval {
            my $fh = IO::File->new($destfile);
            my $call_stack_found = 0;
            my @lines;
            # TODO: maybe use parse_log() here

            while ( $_ = $fh->getline ) {

                # see if we're at the end of a dumped call-stack
                $call_stack_found = 0
                    if ($call_stack_found and (/^\S/ or /^\s*$/));
                
                # see if we're at the beginning of a dumped call-stack
                $call_stack_found = 1 if /^DIE/;

                push @lines, $_
                    if($call_stack_found or /^ERROR\s*:/);

            }

            $msg .= "\nLog file error summary:\n" . join("",@lines);

            # truncate if too big
            if (length($msg) > 10000) {
                $msg = substr($msg, 0, 10000);
            }
            
            #if (GSC::PSE->can("generate_debug_help_text")) {
            #    $msg .= "\n" . GSC::PSE->generate_debug_help_text . "\n";
            #}
        };
        print STDERR "Emailing:\n$msg\n";
        App::Mail->mail(
            To      => 'autobulk',
            Subject => "[CSP Failure] $pse_id $process_to",
            Message => $msg,
        );
    }
    else {
        # compress the done logs
        my $out = join('', `gzip $destfile 2>&1`);
        if ($?) {
            warn "gzip command failed: $out";
        }
    }

    exit 0;
}

sub deal_with_previous_failures {
    my ( $class, $pse_id ) = @_;
    (defined $pse_id) or croak 'must pass a pse_id';

    # TODO: figure out how to do gzip on windows
    return if ( $^O eq 'MSWin32' );

    # find any previous failures
    my @previous_failures = $class->find_previous_failures($pse_id)
        or return;

    # move them to $prev_fail_dir
    for my $src (@previous_failures) {
        my $dst = $class->prev_fail_dir->file( $src->basename );
        rename $src, $dst;
        `gzip $dst`;
    }
}

sub find_previous_failures {
    my ( $class, $pse_id ) = @_;
    ( defined $pse_id ) or croak 'must pass a pse_id';

    my @previous_failures;

    # currently only looking in $fail_dir
    # could expand this to include looking in $assigned_fail_dir
    # or somesuch

    # is this better or worse than a glob?
    $class->fail_dir->recurse(
        callback => sub {
            return if($_[0]->is_dir);
            return if ( $_[0]->basename !~ /^$pse_id\./ );
            push @previous_failures, $_[0];
        }
    );

    return @previous_failures;
}

=head2 cleanup_logs

put stuff here...

=cut

sub cleanup_logs {
    my ($class) = @_;

    my @to_gzip;

    # command_log
    {
        my $dir = $class->command_log_dir;
        while ( $_ = $dir->next ) {
            next if $_->is_dir;
            if ( /\.log$/ and -M $_ > 30 and not -f "$_.gz" ) {
                push @to_gzip, $_;
            }
            elsif ( /\.log\.gz$/ and -M _ > 60 ) {
                unlink $_ or warn "failed to unlink $_: $!";
            }
        }
    }

    # logs that should be compressed nightly
    for my $dir (
        $class->prev_fail_dir,
        $class->done_dir,
        $class->output_dir,
        $class->fail_dir,
    )
    {
        $dir->recurse( callback => sub {
            $_ = shift;
            return if $_->is_dir;
            if (/\.log$/) {
                if ( -z $_ ) {

                    # empty log files are removed
                    unlink $_ or warn "failed to unlink $_: $!";
                }
                else {
                    push @to_gzip, $_;
                }
            }
            elsif ( /\.log\.gz$/ and -M $_ > 12 ) {
                unlink $_ or warn "failed to unlink $_: $!";
            }
        });
    }

    # logs that should not be compressed for a few days
    for my $dir (
        $class->cron_dir,
        $class->jobs_dir,
    )
    {
        while ( $_ = $dir->next ) {
            next if $_->is_dir;
            if ( /\.log$/ and -M $_ > 2 ) {
                push @to_gzip, $_;
            }
            elsif ( /\.log\.gz$/ and -M $_ > 12 ) {
                unlink $_ or warn "failed to unlink $_: $!";
            }
        }
    }

    # look for empty directories under done
#    $done_dir->recurse( callback => sub {
#            $_ = shift;
#            return if $_->is_file;
#    });

    return 1 unless @to_gzip;

    # do the gzip
    my $cmd = "xargs -n 20 -P 3 gzip 2>&1";
    my $fh = IO::File->new or die 'IO::File->new failed';
    $fh->open("| $cmd") or die "open $cmd failed: $!";
    for my $file (@to_gzip) {
        $fh->print("$file\n");
    }
    $fh->close;

    return 1;
}

=head2 setup_process_step_cron_command_line_options

put stuff here...

=cut

sub setup_process_step_cron_command_line_options {

    my %arg;

    App::Getopt->command_line_options(
        'process' => {
            option   => '--process=STRING',
            argument => '=s',
            message  => 'the process step to work with (required)',
            action   => \$arg{process},
        },
        'queue' => {
            option   => '--queue=STRING',
            argument => '=s',
            message  => 'the LSF queue to use',
            action   => \$arg{queue},
        },
        'ignore-locks' => {
            message  => 'ignore filesystem and database locks and initiate jobs anyway',
            action   => \$arg{ignore_locks},
        },
    );

    return \%arg;
}

=head2 process_step_cron

put stuff here...

=cut

# entry point for the process_step_cron script
sub process_step_cron {
    my ( $class, $arg ) = @_;

    my $ignore_locks = $arg->{ignore_locks};
    my $process = delete $arg->{process}
        or croak 'process is required';

    # accept either with underscores or without
    $process =~ s/_/ /g;


    # set up message logging

    my $logfile = $class->cron_logfile("process_step_cron.$process");
    my $log_fh = $logfile->open('>>') or die "open $logfile failed: $!";
    $log_fh->autoflush(1);
    $class->log_fh($log_fh);
    $class->setup_logging_callbacks;
    App::MsgLogger->status_message(
        App::Name->prog_name . ' started on ' . hostname()
        . " as " . getpwuid($<) . " with pid $$ for process $process"
    );
    chmod( 0664, $logfile ) or die "chmod $logfile failed";

    # Don't even start running if we're locked
    # (But at least write to the log file)
    if ( $class->global_locked and !$ignore_locks ) {
        App::MsgLogger->warning_message('Locked: fs lock, exiting');
        exit 0;
    }

    # ensure we have a database connection
    App::DB->dbh or die 'cannot connect to database';

    # figure out the subclass we're working with
    my $p = GSC::Process->get($process)
        or die "process $process not found";
    my $ps_class = $p->ps_subclass_name or die 'no ps_subclass_name ??';
    $ps_class->class;   # auto-generate

    # make sure 1 and only 1 (unix) process per process (step)
    # is running at a time
    my $resource_id = "process_step_cron for $process";
    my $psc_lock = App::Lock->create(
        mechanism   => 'DB_Table',
        resource_id => $resource_id,
        block       => 0,
    );
    if ( !$psc_lock and !$ignore_locks ) {
        $ps_class->status_message("$$ did not get db lock, exiting");
        exit 0;
    }

    # call the cron routine for this process step
    my $rv = eval { $ps_class->cron($arg) };

    # check for errors
    my $error;
    if ($@) {
        $error = $@;
    }
    elsif ( !$rv ) {
        $error = "cron method for $ps_class returned false";
    }

    if ($error) {
        $ps_class->error_message($error);

        # release lock
        $psc_lock->delete if $psc_lock;

        # TODO: send email here?
    }

    die $error if $error;

    App::DB->sync_database or die 'sync failed';
    App::DB->commit or die 'commit failed';

    # release lock
    $psc_lock->delete if $psc_lock;

    $ps_class->status_message("process_step_cron pid $$ done");
    exit 0;
}

sub cron_logfile {
    my ( $class, $process ) = @_;

    $process or croak 'must pass process';

    # check for the log directory
    my $cron_dir = $class->cron_dir;
    die "log directory $cron_dir not found" if ( !-d $cron_dir );

    # make up a log file name
    # one log file per day per process step
    my ($today) = split( / /, App::Time->now );
    $process =~ s/ /_/g;
    my $logfile = $cron_dir->file(
        join( '.', $today, $process, 'log' )
    );

    return $logfile;
}

sub get_done_log {
    my ( $class, %arg ) = @_;

    my $done_dir = $class->done_dir;
    die "$done_dir is not a directory" unless ( -d $done_dir );

    if ( my $pse_id = $arg{pse_id} ) {
        my $glob = "$done_dir/$pse_id.*";
        my @file = glob($glob);
        return unless @file;
        die "more than 1 done log for $pse_id" if ( @file != 1 );
        return file( $file[0] );
    }

    die 'only pse_id supported: fixme';
}

sub parse_log {
    my ( $class, $file, $callback ) = @_;

    croak 'arg 2 must be a subref' unless ref $callback eq 'CODE';

    my $fh;
    if ($file =~ /\.gz$/) {
        $fh = IO::File->new("zcat $file |");
    }
    else {
        $fh = $file->openr;
    }

    my $is_start_of_entry = sub {
        $_[0] =~ /^(STATUS|WARNING|ERROR|SQL|WARN|DIE|DB CONNECT AT):/;
    };

    my $make_entry = sub {
        $_ = shift;

        # strip off whitespace on end
        s/\s+$//;

        # the full entry text
        my $entry = { TEXT => "$_" };

        if (/^(STATUS|WARNING|ERROR|WARN|DIE):\s+(\d{4}-\d\d-\d\d)\s(\d\d:\d\d:\d\d)\s+(.*)$/xms) {
            $entry = {
                %$entry,
                TYPE    => $1,
                DATE    => $2,
                TIME    => $3,
                MESSAGE => $4,
            };
            return $entry;
        }
        elsif (/^SQL:/) {
            $entry->{TYPE} = 'SQL';
            s/^SQL://;
            my @lines = split(/\n/);
            my $sql;
            for my $line (@lines) {

                if ($line =~ /^PARAMS: (.*)$/) {
                    my @p = split(/,\s*/, $1);
                    for my $p (@p) {
                        $p =~ s/^\'|\'$//g;
                    }
                    $entry->{PARAMS} = \@p;
                }
                elsif ($line =~ /^(.*) TIME: (.*) s$/) {
                    $entry->{"$1 TIME"} = $2;
                }
                else {
                    $sql .= "$line\n";
                }
            }

            $sql =~ s/^\s+|\s+$//gm;
            $entry->{SQL} = $sql;
            return $entry;
        }
        elsif (/^DB CONNECT AT: (\d+) \[(.*)\]$/) {
            $entry = {
                %$entry,
                TYPE    => 'DB CONNECT AT',
                TIME    => $1,
                DATE    => $2,
            };
            return $entry;
        }

        die 'failed to parse: ' . $_;
    };

    my $line;
    my $entry_text;
    my $entry;

    while ( $line = $fh->getline ) {

        if ( $is_start_of_entry->($line) ) {

            # make an entry out of the text we've collected
            # up to the start of this new entry

            $entry = $make_entry->($entry_text) if $entry_text;
            $callback->($entry) if $entry;
            $entry_text = '';
        }

        $entry_text .= $line;
    }
    $entry = $make_entry->($entry_text) if $entry_text;
    $callback->($entry) if $entry;

    return 1;
}


=head1 AUTHOR

The WUGSC AutoPipeline Group, C<< <autopipeline at watson.wustl.edu> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CSP

Email autopipeline or open an RT ticket for support.

=head1 COPYRIGHT & LICENSE

fill this in...

=cut

1;

# $Header$

