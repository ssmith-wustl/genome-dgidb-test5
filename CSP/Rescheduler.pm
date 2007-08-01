package CSP::Rescheduler;

use strict;
use warnings;

use GSCApp;
$SIG{__DIE__} = sub{ use Carp; Carp::confess(@_); };
use CSP;
use CSP::PSE;
use CSP::Job;
use App::Accessor;
our @ISA;
push @ISA, 'App::Accessor';


my $DEFAULT_BASE = '/gsc/var/log/confirm_scheduled_pse/rescheduler_cache';

CSP::Rescheduler->accessorize
    (qw(show_critical show_rescheduled show_summary show_ignored report_only
	_base_path _cache_filename email report report_type _log no_log
	reschedule_failed reschedule_lost reschedule_hanged
	reference));


sub new {
    my $class = shift;
    my %p = @_;
    my $self = bless {}, $class;
    $self->show_critical(1);
    $self->show_summary(1);
    $self->email("autobulk\@watson.wustl.edu");
    $self->report('alerts');
    $self->report_type('text');
    $self->reschedule_lost(1); #-- default
    $self->reschedule_hanged(1);
    $self->reschedule_failed(1);

    while(my ($func, $val) = each %p){
	if(defined $val && $self->can($func)){
	    $self->$func($val);
	}
    }

    if($p{no_log} || ($self->report_only && !$p{log_filename})){
	$self->_log(IO::Handle->new_from_fd(*STDOUT, 'w'));
    }
    else{
	if($p{log_filename}){
	    $self->_log(IO::File->new($p{log_filename}, '>+'));
	}
	else{
	    my $path = $class->_base_path || $DEFAULT_BASE;
	    my @localtime = localtime;
	    my $name = 'csp.log.'.(1900+$localtime[5]).'-'.($localtime[4]+1).'-'.$localtime[3];
	    $self->_log(IO::File->new($path.'/'.$name, '>>'));
	}
    }
    
    $self->reference("$ENV{USER}\@$ENV{HOST}.$$");
    $self->log("----------------------------------------");
    $self->log("CSP::Rescheduler Begins at ".localtime());
    $self->log("----------------------------------------");
    
    return $self;
}

sub log{
    my $self = shift;
    my $msg = shift;
    return if $self->no_log || !$self->_log;
    $self->_log->print($self->reference." : ".$msg."\n");
    1;
}

sub DESTROY{
    my $self = shift;
    $self->log("CSP::Rescheduler completes at ".localtime());
    $self->_log->close;
}

sub cache_filename{
    my $class = shift;
    my %p = @_;
    
    return $class->_cache_filename if ref $class && $class->_cache_filename;
    my $path = $class->_base_path || $DEFAULT_BASE;
    
    return $path.'/csp.cache';
}

sub get_cache{
    my $class = shift;
    my %p = @_;
    my $lost_file = $class->cache_filename(%p);
    my @stuff = split /\s+/mixs, `cat $lost_file`;
    my %already;
    while(@stuff){
	my $pse = shift @stuff;
	$already{$pse} = [split ',', shift @stuff];
    }
    return %already;
}
sub set_cache{
    my $class = shift;
    my %p = @_;
    my $lost_file = $class->cache_filename(%p);
    open(O, '>'.$lost_file) || die "couldn't open $lost_file";
    while(my ($pseid, $ref) = each %p){
	print O $pseid.' '.$ref->[0].','.$ref->[1].' ';
    }
    return 1;
}

sub get_critical_pses{
    my $class = shift;
    my %params = @_;
    
    my $self = (ref $class ? $class : $class->new(%params));
    
    foreach (keys %params){
	if($self->can($_)){
	    $self->$_($params{$_});
	}
    }
    #----------- go through the scheduling
    my %already = $self->get_cache(%params);
    my @csp_pses = (exists $params{'csp_pse'} ? @{$params{'csp_pse'}} : CSP->find_jobs(%params));

    my %critical;
    
    foreach my $cp(@csp_pses){
	$cp->refresh;
	next unless $cp->is_failed;
	next unless $cp->alert_informatics($already{$cp->pse_id}->[1]) 
	    || $cp->beyond_help($already{$cp->pse_id}->[1]);
	$critical{$cp->process} = [] unless exists $critical{$cp->process};
	push @{$critical{$cp->process}}, $cp;
    }

    return %critical;
}


sub auto_reschedule{
    my $class = shift;
    my %params = @_;

    my $self = (ref $class ? $class : $class->new(%params));

    foreach (keys %params){
	if($self->can($_) && defined $params{$_}){
	    $self->$_($params{$_});
	}
    }
    my $report_indeed = (grep {defined $self->$_ && $self->$_} 
			 qw(show_summary show_critical show_ignored show_rescheduled));
    
    #----------- prepare the report first
    my $report = App::Report->create();
    my $title = "CSP::Rescheler Report";
    if($self->reschedule_lost + $self->reschedule_failed + $self->reschedule_hanged < 3){
	my @types;
	push (@types, "lost") if $self->reschedule_lost;
	push (@types, "hanged") if $self->reschedule_hanged;
	push (@types, "failed") if $self->reschedule_failed;

	$title .= " to analyze ".join(" and ", @types)." pses, only.";
    }
    else{
	$title .= '.';
    }
    if($self->report_only){
	$title .= ' (report only)';
    }
    
    $report->header($title);
    if($report_indeed){
	if($self->show_summary){
	    $self->{summary} = {};
	    $report->create_section(name => 'summary',
				    title => 'Summary of Failures', 
				    sort_column => 3)
		->header('Action', 'Failure Type', 'Process', 'Count');
	    
	}
	if($self->show_critical){
	    $report->create_section(name => 'critical',
				    title => "Critical Failures\n\nNo rescheduling occurred.  These require immediate attention.", 
				    sort_column => 2)
		->header('Failure', 'Process', 'PSE', 'Status', 'User', 'Date', 'Job ID');
	}
	if($self->show_rescheduled){
	    $report->create_section(title => "Rescheduled PSEs\n\nThese were rescheduled.", 
				    name => 'rescheduled',
				    sort_column => 3)
		->header('Failure', 'Retry#',  'Process', 'PSE', 'Status', 'User', 'Date', 'Job ID');
	}
	if($self->show_ignored){
	    $report->create_section(title => "Ignored Failures\n\nThese are pses that are ignored by the auto-rescheduler because they have reached the max they should be rescheduled.  Although it says the auto-rescheduler is ignoring them, these demand immediate attention.", 
				    name => 'ignored',
				    sort_column => 2)
		->header('Failure', 'Process', 'PSE', 'Status', 'User', 'Date', 'Job ID');
	}
    }
    
    #----------- go through the scheduling
    my %already = $self->get_cache(%params);
    my @csp_pses = (exists $params{'csp_pse'} ? @{$params{'csp_pse'}}
		    : CSP->find_jobs(%params));
    my %current;

    foreach my $cp(@csp_pses){
	my $problem_type = $cp->is_problematic;
	next unless $problem_type;
	my $doing_report = 'reschedule_'.$problem_type;

	unless ($self->$doing_report){
	    #----- if we're only doing some reports, make sure we don't kill the cache
	    if(exists $already{$cp->pse_id}){
		$current{$cp->pse_id} = $already{$cp->pse_id};
	    }
	    next;
	}

	my ($result, $object, $count) = $self->reschedule_and_report
	    ($problem_type, $cp, $already{$cp->pse_id}, $report);
	if($result){
	    $current{$cp->pse_id} = [$object, $count];
	}
    }
    App::DB->sync_database;
    App::DB->commit;

    my %types;
    if($self->show_summary){
	my $summary = $report->get_section('summary');
	while(my ($category, $data1) = each %{$self->{summary}}){
	    while(my ($type, $data2) = each %$data1){
		$types{$category} = 1;
		while(my ($process, $count) = each %$data2){
		    $summary->add_data($category,$type,$process,$count);
		}
	    }
	}
    }
    
    my @types = keys %types;
    if($report_indeed){
	my $message = $report->generate(format => 'Text');
	
	if($self->report eq 'always'
	   || ($self->report eq 'rescheduled' && (grep {$_ =~ /Retry|Alert/} @types))
	   || ($self->report eq 'alerts' && exists $types{'Alert!'})){
	    
	    if($self->report_type eq 'email'){
		$self->log('Emailing report to '.$self->email);
		App::Mail->mail(To => $self->email,
				From => "CSP Watcher <autopipeline\@watson.wustl.edu>",
				Subject => "CSP Failures",
				Message => $message,
				);
	      }
	    else{
		$self->log('Printing report');
		print $message."\n";
	    }
	}
    }
    
    #=== update the files
    unless($self->report_only){
	$self->set_cache(%current);
    }    
    return 1;
}

sub reschedule_and_report{
    my ($self, $type, $csp_pse, $prior_attempts, $report) = @_;
    
    my $attempt_count;
    my $base_count = (($prior_attempts->[0] && $prior_attempts->[0] eq $type) 
		      ? $prior_attempts->[1] : 0);
    $attempt_count = $base_count+1;
    
    #-------------- SHOULD THIS BE RESCHEDULED?
    if($csp_pse->should_reschedule($attempt_count)){
	my $qualifier = '';
	
	if($self->can_reschedule($type)){
	    $base_count = $attempt_count;
	    unless($csp_pse->reschedule()){
		$self->log("Failed to reschedule pse_id ".$csp_pse->pse_id." : ".$csp_pse->error_message);
		return (0);
	    }
	    $self->log("Rescheduled $type pse_id ".$csp_pse->pse_id);
	    $self->_increment_summary("Retry $attempt_count", $type, $csp_pse->process);
	}
	else{
	    $self->log("Report only.  No attempt to reschedule $type pse_id ".$csp_pse->pse_id);
	    $self->_increment_summary("Ready to retry $attempt_count", $type, $csp_pse->process);
	}
	
	#--- add to the rescheduled list
	if($self->show_rescheduled){
	    $report->get_section('rescheduled')->add_data(ucfirst($type), $attempt_count, $csp_pse->process, $csp_pse->pse_id, $csp_pse->pse_status, $csp_pse->user, $csp_pse->date_scheduled, $csp_pse->job_id);
	}
    }
    #-------------- IS IT WORTHY OF AN ALERT?
    elsif($csp_pse->alert_informatics($attempt_count)){
	$self->log("Alerting informatics of over-fail on $type pse ".$csp_pse->pse_id);
	$self->_increment_summary('Alert!', $type, $csp_pse->process);
	if($self->show_critical){
	    $report->get_section('critical')->add_data(ucfirst($type), $csp_pse->process, $csp_pse->pse_id, $csp_pse->pse_status, $csp_pse->user, $csp_pse->date_scheduled, $csp_pse->job_id);
	}
	$base_count = $attempt_count unless $self->report_only; #-- for the record
    }
    #-------------- IS IT BEYOND HELP?
    elsif($csp_pse->beyond_help($attempt_count)){ 
	$self->_increment_summary('auto-ignored', $type, $csp_pse->process);
	if($self->show_ignored){ #--- ignored because it's much too high
	    $report->get_section('ignored')->add_data(ucfirst($type), $csp_pse->process, $csp_pse->pse_id, $csp_pse->pse_status, $csp_pse->user, $csp_pse->date_scheduled, $csp_pse->job_id);
	}
    }
    else{ #--- no longer a problem
	return (0);
    }
    return (1, $type, $base_count);
}

sub can_reschedule{
    my $self = shift;
    my $type = shift;
    return 0 if $self->report_only;
    my $func = 'reschedule_'.$type;
    return 0 unless $self->$func;
    1;
}

sub _increment_summary{
    my $self = shift;
    my ($category, $type, $process) = @_;
    $self->{summary}{$category} = {} unless exists $self->{summary}{$category};
    $self->{summary}{$category}{$type} = {} unless exists $self->{summary}{$category}{$type};
    $self->{summary}{$category}{$type}{$process} = 0 
    unless exists $self->{summary}{$category}{$type}{$process};
    
    ++$self->{summary}{$category}{$type}{$process}; 
    
    1;
}

1;


=head1 NAME

CSP::Rescheduler

=head2 DESCRIPTION

A module to deal with analyzing and rescheduling the sets of pses that are scheduled, confirming, or failed.

=head2 SYNOPSIS

#!/gsc/bin/perl

use GSCApp;
use strict;
use warnings;
use CSP::Rescheduler;
App->init;


CSP::Rescheduler->auto_reschedule(report => 'always', report_type => 'email');


## THAT'S IT!!!

=head1 FUNCTIONS YOU CARE ABOUT

=over 4

=item new ( PARAMS )

Create a new object.  The set of params will override the defaults.  The default 'defined' values are as follows:

 show_critical = 1
 show_summary = 1
 email = autobulk@watson.wustl.edu
 report = alerts
 report_type = text

=item auto_reschedule( PARAMS )

The function to actually reschedule and generate a report.  It can be called in class or in functional context.  Any of the report options can be set in the parameters, including the email, report_type, or report values. See 'Report Options' for the full set of options.

By default, auto_reschedule will call CSP->find_jobs to get the CSP::PSE objects to test.  

If you set the csp_pse parameter to an arrayref of CSP::PSE objects, it will use those instead.


=item reschedule_and_report ( failure_type, CSP::PSE, [prior_failure_type, prior_number_of_rescheduling_attempts], App::Report );

Run the relatively complex rescheduling algorithm to reschedule-or-ignore-or-alert and add its information to the report, as necessary.

=item cache_filename ( ?PATH? )

Sets the cache filename.  This is on the phase-out to use the database

=item get_cache ()

Gets a hash of pse_ids to [prior-rescheduling-type, number-of-attempts].  This information is stored in the database

=item set_cache ( %new_cache )

Takes in a hash of pse_ids to [rescheduling-type, total-number-of-attempts-to-date].  This information is then stored or updated in the database.

=back

=head2 REPORT OPTIONS

When you're configuring a CSP::Rescheduler, the following are the report options you can configure, which can be set on the instance itself or passed in as parameters to auto_reschedule:

=over 4

=item show_summary

Show the summary of all alerts, broken down by alert type ('lost' or 'failed'), the rescheduling category ('auto-ignored', 'Alert!', or 'Retry 1,2,or3'), the process, and the number of pses therein

=item show_critical

Show the 'Critical Alerts!' section of the report, which documents all PSEs that have *just now* reached a point at which they will no longer be auto-rescheduled because they have exceeded the maximum retry mark.

=item show_rescheduled

Show all the PSEs that were rescheduled

=item show_ignored

Show all pses that are auto-ignored, which DOES NOT MEAN that the DEVELOPER SHOULD IGNORE THEM.  It means that the SCHEDULER is ignoring them, which means they ave passed the 'critical alerts!' phased and have already been reported and continue to be a problem.

=item report

Indicates when a report is generated.  Values are 'always', 'rescheduled' (if anything is rescheduled or reaches alert status), 'alerts' (critical alerts only), 'never'

=item report_type

Indicates the type of report.  Presently, one of 'email' or 'text'

=item email

Indicate the To: address in the case of an email submission.

=item report_only

If on, indicates that one should neither actually reschedule nor update the database/cache on execution, but only generate the report.

=item reschedule_lost, reschedule_failed, reschedule_hanged

Indicates that these types of failures should have rescheduling attempted.  

=cut





