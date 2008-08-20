package CSP::PSE;


#-- this is an object that has everything you'd ever want to know about a job that is in the scheduled-confirming-confirm state
use strict;
use warnings;
use Date::Calc;

use base 'App::Accessor';



my %PROCESS_COUNT = (
    'analyze traces'          => 4,
    'add read to mp assembly' => 1,

    #- there are over 1000 here right now. maybe we can make it non-0 later
    'assemble 454 regions' => 0,

    'align reads to recent runs'             => 2,
    'analyze 454 output'                     => 0,
    'analyze 454 run'                        => 0,
    'autofinish'                             => 1,
    'mkcs'                                   => 1,
    'import external reads'                  => 0,
    'run started'                            => 0,
    'cycle completed'                        => 0,
    'run completed'                          => 0,
    'configure image analysis and base call' => 0,
    'make default offsets'                   => 0,
    'extract image features'                 => 0,
    'call bases'                             => 0,
    'configure alignment'                    => 0,
    'run alignment'                          => 0,
    'generate lane summary'                  => 0,
    'create short read format'               => 0,
    'analysis completed'                     => 0,
    'import sequence'                        => 0,
    'clean run'                              => 0,
    'copy run'                               => 0,
    'remove run'                             => 0,
    'prepare read submission'                => 0,
    'submit reads'                           => 0,
    'transfer submission'                    => 0,
    'gather submission results'              => 0,
    'make library start site'                => 0,
    'build sequence db'                      => 0,

    'design amplicons' => 0,
    'annotate reference sequence' => 0,
                 
    #Finishing QA steps
    'analyze finished clone for qa'                      => 0,
    'submit finished clone for coordinator approval'     => 0,
    'submit finished clone to qa'                        => 0,
    'claim finished clone for qa'                        => 0,
    'hold finished clone in qa'                          => 0,
    'approve finished clone quality'                     => 0,
    'reject finished clone quality'                      => 0,
    'submit finished clone to finisher to make changes'  => 0,
    'submit finished clone to coor to approve changes'   => 0,
);


my %PROCESS_HANG_LENGTH = (
			   #-- format is days,hours,minutes,seconds
			   'mkcs'           => [1],
			   'analyze traces' => [0,6,0,0],
			   );


CSP::PSE->accessorize(qw(pse_id process ps_id date_scheduled user 
			 pse_status pse_result job_id _job no_job_found
			 error_message));


sub new{
    my $class = shift;
    my $self = $class->new_nocheck(@_);
    $self->resolve_missing_information;
    return $self;
}


sub new_nocheck{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my %p = @_;
    #--- we assume here all checking is done somewhere else
    while(my ($field, $val) = each %p){
	$self->$field($val);
    }    
    return $self;
}

sub new_from_pse_id{
    my $class = shift;
    my $pse_id = shift;
    my $pse = GSC::PSE->get(pse_id => $pse_id);
    my $self = {pse_id => $pse->pse_id};
    bless $self, $class;
    $self->resolve_missing_information;
    return $self;
}


sub count_for_process{
    my $self = shift;
    return $PROCESS_COUNT{$self->process} if exists $PROCESS_COUNT{$self->process};
    my $ps = GSC::ProcessStep->get(ps_id => $self->ps_id);
    return 2 if $ps->pp_type;
    return 0;
}

sub should_reschedule{
    #--- returns true if it maches all criteria that it should be attempted
    my $self = shift;
    my $prior_count = shift;
    my $top_count = $self->count_for_process;
    return 0 if $self->alert_informatics($prior_count) || $self->beyond_help($prior_count);
    return 1 if $self->is_lost || $self->is_hanged || $self->is_failed;
    0;
}

sub reschedule{
    #-- commit on your own, man
    my $self = shift;
    
    #--- Lock the row
    my $savepoint = 'to_rescheduled_'.$self->pse_id;
    unless(App::DB->dbh->do(qq/savepoint $savepoint/)){
	return 0;
    }
    unless(App::DB->dbh->do(qq/select * from process_step_executions where pse_id = ? for update/,
			    undef, $self->pse_id)){
	return 0;
    }
    $self->refresh; #-- always refresh right now
    unless($self->is_problematic){
	App::DB->dbh->do(qq/rollback to savepoint $savepoint/);
	  $self->error_message("pse is no longer problematic");
	  return 0;
      }
    
    unless(App::DB->dbh->do(qq/update process_step_executions 
			    set psesta_pse_status = 'scheduled',
			    pr_pse_result = null 
			    where pse_id = ?/, undef, $self->pse_id)){
	App::DB->dbh->do(qq/rollback to savepoint $savepoint/);
	  return 0;
      }    
    
    if($self->is_failed){
	#-- we're done
	return 1;
    }
    elsif($self->is_lost){
	#---- delete the job id and reschedule it 
	unless(App::DB->dbh->do(qq/delete from pse_job where pse_id = ?/, undef, $self->pse_id)){
	    App::DB->dbh->do(qq/rollback to savepoint $savepoint/);
	      return 0;
	  }
    }
    elsif($self->is_hanged){
	#--- kill the job, delete it, and reschedule
	my $cmd = 'bkill '.$self->job_id;
	my $result = `$cmd`;
	chomp $result;
	unless($result =~ / is being terminated/){
	    return 0;
	}
	unless(App::DB->dbh->do(qq/delete from pse_job where pse_id = ?/, undef, $self->pse_id)){
	    App::DB->dbh->do(qq/rollback to savepoint $savepoint/);
	      return 0;
	  }
    }
    1;
}

sub beyond_help{
    my $self = shift;
    my $prior_count = shift;
    $prior_count = 0 unless $prior_count;
    return ($prior_count > ($self->count_for_process + 1));
}


sub alert_informatics{
    my $self = shift;
    my $prior_count = shift;
    $prior_count = 0 unless $prior_count;
    return ($prior_count == ($self->count_for_process + 1));
}

sub refresh{
    my $self = shift;
    my ($status, $result, $jobid) = App::DB->dbh->selectrow_array
	(qq/select psesta_pse_status, pr_pse_result, job_id
	 from process_step_executions e left join pse_job j on e.pse_id = j.pse_id
	 where e.pse_id = ?/, undef, $self->pse_id);

    my $changed = 0;
    if($status ne $self->pse_status){
	$changed = 1;
	$self->pse_status($status);
    }
    if(($result && (!$self->pse_result || $self->pse_result ne $result))
	|| (!$result && $self->pse_result)){
	$changed = 1;
	$self->pse_result($result);
    }
    
    if(($jobid && $self->job_id ne $jobid)
       || (!$jobid && $self->job_id)){
	$changed = 1;
	$self->job_id($jobid);
	#--- job id, we can lose the old job, if therre is one
	$self->_job(undef);	
    }
    elsif($changed){ #-- if the pse is changed, we clear the job (but not the job-id)
	$self->_job(undef);
    }
    $changed;
}

sub resolve_missing_information{
    my $self = shift;
    die "cannot make object without pse_id" unless $self->pse_id;
    my $pse = GSC::PSE->get($self->pse_id);

    foreach my $pse_func(qw(ps_id pse_status pse_result date_scheduled)){
	unless($self->$pse_func){
	    $self->$pse_func($pse->$pse_func);
	}
    }
    unless($self->process){
	my $ps = $pse->get_process_step;
	$self->process($ps->process_to);
    }
    unless($self->user){
	my ($unix_login) = App::DB->dbh->selectrow_array(qq/select unix_login from gsc_users g, employee_infos e where e.gu_gu_id = g.gu_id and e.ei_id = ?/, undef, $pse->ei_id);
	$self->user($unix_login);
    }
    unless($self->job_id){
	if($self->pse_status eq 'scheduled' || $self->pse_status eq 'confirming'){
	    my $ji = GSC::PSEJob->get(pse_id => $pse);
	    if($ji){
		$self->job_id($ji->job_id);
	    }
	}
    }
    1;
}

sub get_pse{
    my $self = shift;
    return GSC::PSE->get(pse_id => $self->pse_id);
}

sub get_process_step{
    my $self = shift;
    return GSC::ProcessStep->get(ps_id => $self->ps_id);
}

sub pretty{
    my $self = shift;
    
    return $self->process." pse ".$self->pse_id.($self->job_id ? " with job ".$self->job_id : '')
	. " ( ".$self->pse_status.($self->pse_result ? " ".$self->pse_result : '')
	. ' by '. ($self->user ? $self->user : 'an unknown user')." on ".$self->date_scheduled.')';
}

sub get_job{
    my $self = shift;
    return unless $self->job_id && !CSP->blades_down();
    return if $self->no_job_found;
    return $self->_job if $self->_job;
    
    my $job = CSP::Job->new(job_id => $self->job_id);
    unless($job){
	$self->no_job_found(1);
	return;
    }
    $self->_job($job);
    return $job;
}

#--- this is to generate the job object from a bigger bjobs command, so you can do a bigger scale thing that doesn't take too much time
sub process_job_line{
    my $self = shift;
    my $line = shift;
    return unless $line;
    my $job = CSP::Job->new_from_line($line);
    return unless $self->_job($job);
    return 1;
}

sub is_problematic{
    my $self = shift;
    return 'failed' if $self->is_failed;
    return 'lost' if $self->is_lost;
    return 'hanged' if $self->is_hanged;
}

sub is_hanged{
    my $self = shift;
    return 0 unless ($self->pse_status eq 'confirming' || $self->pse_status eq 'scheduled') 
	&& $self->job_id;
        
    my $job = $self->get_job;
    return 0 unless $job;
    
    #--- get the last modify time
    #    We want to do this on the filename, but there isn't an easy way to do that.
    #    So now we're saying any confirm-scheduling job that's 
    #    been running for more than 24 hours

#    my $filename = CSP->job_logfile($self->pse_id, $self->process);
#    unless (-f $filename){ #check filename exists 
#	warn "CAN'T FIND FILE $filename\n";
#	return 0;
#    }
#    my @s = stat $filename;
#    my @last_modify = Date::Calc::Time_to_Date($s[9]);



    my $now = App::Time->now();
    my @nowtime = split /[\:\- ]/, $now;
    
    my $starttime = $job->submit_time;
    my ($month, $day, $hour, $min) = $starttime =~ /^(\w+)\s+(.*)\s+(\d+)\:(\d+)/;
    my @blade_starttime = ($nowtime[0], Date::Calc::Decode_Month($month), $day, $hour, $min, 0);;
    
    my @timediff = Date::Calc::Delta_DHMS(@blade_starttime, @nowtime);
    
    return $self->_hanging_too_long(@timediff);
}

sub _hanging_too_long{
    my $self = shift;
    my ($days, $hours, $mins, $secs) = @_;
    if(exists $PROCESS_HANG_LENGTH{$self->process}){
	my @comp = @{$PROCESS_HANG_LENGTH{$self->process}};
	my $diffint = $days * 1000000
	    + $hours * 10000
	    + $mins * 100
	    + $secs;
	my $compint = $comp[0] * 1000000
	    + $comp[1] * 10000
	    + $comp[2] * 100
	    + $comp[3]; 
	return ($diffint > $compint);
    }
    else{
	return ($days || ($hours > 4));
    }
}

sub is_lost{
    my $self = shift;
    if($self->job_id){
	if ($self->job_id =~ /\D/){
	    #-- if it's not entirely numeric, it's generally not an error
	    #   but if it's been that way for a long time, 
	    my @date = $self->job_id =~ /^\w+\@\d+\.(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
	    if(@date){
		my ($days) = Date::Calc::Delta_DHMS(@date, Date::Calc::Today_and_Now);
		if($days >= 1){
		    return 1;
		}
	    }
	    else{
		return 1;
	    }
	    return 0;
	}
    }
    if($self->job_id){
	return 1 if $self->no_job_found();
    }
    elsif($self->pse_status eq 'confirming'){ 
	return 1;
    }
    0;
}

sub is_failed{
    my $self = shift;
    #--- remember, a job_id indiciates it's locked
    return ($self->pse_status eq 'confirm' && !$self->job_id);
}


sub get_fail_logs{
    my $self = shift;	
    my $cmd = "find /gsc/var/log/confirm_scheduled_pse/{fail,prev_fail}/".$self->pse_id.".* 2> /dev/null";
    my @potential = `$cmd`;
    chomp(@potential);
    return @potential;
}


sub current_fail_log{
    my $self = shift;	
    my $cmd = "find /gsc/var/log/confirm_scheduled_pse/fail/".$self->pse_id.".* 2> /dev/null";
    my @potential = `$cmd`;

    unless(@potential){ #-- check previous fail!
	$cmd = "find /gsc/var/log/confirm_scheduled_pse/prev_fail/".$self->pse_id.".* 2> /dev/null";
	@potential = `$cmd`;
    }
    chomp @potential;
    return unless @potential;
    return $potential[0] if @potential == 1;
    
    @potential = sort @potential;
    return $potential[$#potential];
}


sub parse_fail_log{
    #--- if you want the entire file, you're on your own
    my $self = shift;
    my %p = @_;
    
    my $filename;
    if($p{'filename'}){
	if($p{filename} !~ /\//){
	    my $cxd = "find /gsc/var/log/confirm_scheduled_pse/{fail,prev_fail}/$p{filename}\*";
	    my @val = `$cxd`;
	    chomp @val;
	    unless(@val){
		warn "no file $p{filename} found";
		return;
	    }
	    $filename = shift @val;
	}
	else{
	    $filename = $p{'filename'};
	}
    }
    else{
	$filename = $self->current_fail_log();
    }

    unless ($filename){
	#warn "cannot find file for ".$self->pse_id."\n";
	return;
    }

    my @show =($p{show} ? (ref $p{show} ? @{$p{show}} : $p{show}) : ());
    my @hide =($p{hide} ? (ref $p{hide} ? @{$p{hide}} : $p{hide}) : ());
    
    my %tags = 
	(
	 'error' => 'ERROR|DIE',
	 'warn' => 'WARN|WARNING',
	 'status' => 'STATUS',
	 'die' => 'DIE',
	 'sql' => 'SQL|PARAMS',
	 );
    foreach($p{show_tags} ? (ref $p{show_tags} ? @{$p{show_tags}} : ($p{show_tags})) : ()){
	if(exists $tags{$_}){
	    push @show, $tags{$_};
	}
    }
    foreach($p{hide_tags} ? (ref $p{hide_tags} ? @{$p{hide_tags}} : ($p{hide_tags})) : ()){
	if(exists $tags{$_}){
	    push @hide, $tags{$_};
	}
    }
    
    #--- default to show error and die if not otherwise specified
    unless(@show){
	unless(grep {$_ =~ /ERROR/} @hide){
	    @show = ($tags{'error'});
	}
    }
    chomp $filename;
    my $cmd = ($filename =~ /.gz$/ ? 'zless' : 'cat'). " $filename ";

    if(@show){
	$cmd .= "| egrep  '^(".join('|', @show).")\\s*\\:' ";
    }
    if(@hide){
	$cmd .= "| egrep -v '^(".join('|', @hide).")\\s*\\:' ";
    }
    my @results = `$cmd`;
    chomp @results;
    return @results;
}

sub generic_errors{
    my $self = shift;
    my $log = $self->_tokenify([$self->get_error_log()]);

    my @generic;

    foreach my $line(@$log){
	my @line;
	foreach my $word (@$line){
	    if($word =~ /\d/){
		push @line, &_an_string($word);
	    }
	    else{
		push @line, $word;
	    }
	}
	push @generic, join(" ",@line);
    }
    
    return @generic;
}


sub is_generic_string{
    my $self = shift;
    my $word = shift;
    return 1 if $word =~ /(<date>|<time>|<upstream dna name>|<sequence dna name>|<trace or read name>|<alphanum>|<numeric>|<alpha>)/;
    0;
}

sub _an_string{
    my $word = shift;
    
    my $altword = '';
    if($word =~ /\d/){
	if($word =~ /\W/){ #--- non-word char
	    #--- check for date and time first
	    return '<date>' if $word =~ /^\d+[\-\/]\d+[\-\/]\d+$/;
	    return '<time>' if $word =~ /^\d+\:\d+(\:\d+)?$/;
	    return '<upstream dna name>' if $word =~ /^\w{1,4}-\w+$/;
	    return '<sequenced dna name>' if $word =~ /^\w{1,4}-\w+\.\w-\d+$/;
	    return '<trace or read name>' if $word =~ /^\w{1,4}-\w+\.\w\d+(\-\d+)?$/;
	    
	    return "'".&_an_string($1)."'" if $word =~ /^\'([^\']+)\'$/;
	    return "\"".&_an_string($1)."\"" if $word =~ /^\"([^\"]+)\"$/;


	    while($word =~ /(\W*)(\w+)(\W)/g){
		$altword .= $1.&_an_string($2).$3;
	    }
	    if($word =~ /(\w+)$/){
		$altword .= &_an_string($1);
	    }
	    return $altword;
	}
	
	if($word =~ /\D/){
	    return '<alphanum>';
	}
	else{
	    return '<numeric>';
	}
    }
    return '<alpha>';
}
		    
		    


sub get_error_log{
    my $self = shift;

    unless(exists $self->{error_log}){
	my $log_file = $self->current_fail_log();
	$self->{error_log} = [$self->parse_fail_log(show_tags => 'error', filename => $log_file)];
    }
    return @{$self->{error_log}};
}

sub find_similar_errors{
    my $self = shift;
    my %p = @_;
    
    return unless $self->is_failed;

    my $threshold = $p{threshold} || .85;
    my $threshold_type = $p{threshold_type} || 'adjusted';

    my $log_file = $self->current_fail_log();
    $self->{error_log} = [$self->parse_fail_log(show_tags => 'error', filename => $log_file)];
    return unless @{$self->{error_log}};
    
    #--- get the other current failures
    my $ps = $self->get_process_step;
    my $pro_process_to = $ps->process_to;
    $pro_process_to =~ y/ /_/;
    my @possible_logs = `find /gsc/var/log/confirm_scheduled_pse/fail/*.$pro_process_to.*`;
    chomp @possible_logs;
    my @results;
    foreach my $file(@possible_logs){
	next if $file !~ /\/(\d+)\.$pro_process_to\./ || $file eq $log_file;
	my ($pse_id) = $1;
	die "no pse-id for file $file" unless $pse_id;
	my $csp_pse = CSP::PSE->new_from_pse_id($pse_id);
	my $other_log = [$csp_pse->parse_fail_log(show_tags => 'error', filename => $file)];
	my $result =[$pse_id, 
		     $self->compare_error_logs($self->{error_log}, 
					       $other_log,
					       ),
		     $file];
	next if $result->[3] < 10; #--- sample size
	if($threshold_type eq 'adjusted'){
	    next if $result->[2] < $threshold;
	}
	else{
	    next if $result->[1] < $threshold;
	}
	push @results, $result;
    }
    
    my @sorted = sort {$b->[2] <=> $a->[2]} @results;
    return @sorted;
}


sub compare_errors{
    my $self = shift;
    my $other = shift;
    my %params = @_;
    
    return 0 unless $self->is_failed && $other->is_failed;

    my $threshold_type = $params{threshold_type} || 'adjusted';
    
    unless($self->{error_log}){
	my $my_log_file = $self->current_fail_log();
	$self->{error_log} = [$self->parse_fail_log(show_tags => 'error', 
						    filename => $my_log_file)];
    }
    return 0 unless @{$self->{error_log}};
    
    unless($other->{error_log}){
	my $other_log_file = $other->current_fail_log();
	$other->{error_log} = [$other->parse_fail_log(show_tags => 'error', 
						      filename => $other_log_file)];
    }
    return 0 unless @{$other->{error_log}};
    
    my @result = $self->compare_error_logs($self->{error_log}, $other->{error_log});
    
    #--- need a sufficient sample size
    return -1 unless $result[3] >= 10;
    return ($threshold_type eq 'adjusted' ? $result[1] : $result[0]);
}

sub compare_error_logs{
    my $self = shift;
    my $log1 = $self->_tokenify(shift);
    my $log2 = $self->_tokenify(shift);
    my %p = @_;

    #-- we actually go in reverse
    my @result;
    my $i = scalar(@$log1);
    my $j = scalar(@$log2);

    my %total = (similar => 0,
		 same => 0,
		 same_filtered => 0,
		 total => 0,
		 total_adj => 0,
		 numeric => 0,
		 mixeduse => 0,
		 similar_adj => 0,
		 );

    while($i && $j){
	--$i;
	--$j;
	#--- compare the two
	my %result = (similar => 0,
		      same => 0,
		      same_filtered => 0,
		      total => 0,
		      total_adj => 0,
		      numeric => 0,
		      mixeduse => 0,
		      similar_adj => 0,
		      );

	foreach my $index(0..$#{$log1->[$i]}){
	    last if $index > $#{$log2->[$j]};
	    ++$result{total};
	    if($log1->[$i]->[$index] eq $log2->[$j]->[$index]){
		$result{same}++; #-- same
	    }
	    
#	    if($self->is_generic_string($log1->[$i]->[$index])){
#		++$result{generic_tag};
#		next;
#	    }
#	    elsif($log1->[$i]->[$index] =~ /\d/) {  #--- to replace next line
	    if($log1->[$i]->[$index] =~ /\d/) { 
		if($log1->[$i]->[$index] =~ /\D/){ #--- not strictly numeric
		    if($log1->[$i]->[$index] =~ /\D*\d+\D*/){ #--- a mix of numbers and things
			++$result{mixeduse};
		    }
		}
		else{ #--- strictly numeric
		    $result{numeric}++;
		}
		
		if($log1->[$i]->[$index] eq $log2->[$j]->[$index]){
		    $result{same_filtered}++; #-- same
		}
	    }
	}

	push @result, \%result;
	foreach (keys %result){
	    $total{$_} += $result{$_};
	}
    }
    if($total{total} == 0){
	return (0,0,0,0);
    }
    else{
	$total{similar} = sprintf("%.4f", ($total{same} / $total{total}));
#	$total{total_adj} = $total{total} - $total{numeric} - $total{mixeduse} - $total{generic_tag}; # to replace next line
	$total{total_adj} = $total{total} - $total{numeric} - $total{mixeduse};

	if($total{total_adj} == 0){
	    $total{similar_adj} = $total{total_adj} = 0;
	}
	else{
	    $total{similar_adj} = sprintf("%.4f", (($total{same} - $total{same_filtered}) / ($total{total} - $total{mixeduse} - $total{numeric})));
	    $total{total_adj} = ($total{total} - $total{mixeduse} - $total{numeric});
	}
    }
    return ($total{similar}, $total{similar_adj}, $total{total}, $total{total_adj});
}

sub _tokenify{
    my $self = shift;
    my $aref = shift;
    
    my @result;
    foreach my $s(@$aref){
	#-- monitor whitespace
	chomp $s;
	$s =~ s/^\s+//;
	$s =~ s/\s+$//;
	#$s =~ s/(\s)\s+/$1/g;
	#--get rid of the heading
	$s =~ s/^ERROR\s*\:\s*\d+-\d+-\d+\s*\d+\:\d+\:\d+\s*//;
	
	push @result, [split /\s+/, $s];
    }
    return \@result;
}
	
1;


=head1 TITLE

CSP::PSE

=head1 SYNOPSIS

=head1 FUNCTIONS

=over 4
    
=item user 

Returns the unix login for the person who executed the step

=item pse_id, process, ps_id, date_scheduled, user, pse_status, pse_result, job_id

Returns exactly what you expect them to

=item new (PARAMS)

create a new object from the parameters. There must be at least enough information to correctly derrive a job, and that is generally a pse_id.  All additional information will be derrived

=item new_from_pse_id (pse_id)

Just like it says.

=item new_nocheck ( PARAMS )

*dangerous*!  No extra information is autogenerated.  This is generally, mostly, for internal use in the CSP package.


=item count_for_process()

Returns the number of times a pse of this process type should have rescheduling attempted on it.

=item should_reschedule( prior_count )

Boolean to return true if this pse should be automatically rescheduled at this time.  Note that this is for auto-rescheduling only, and will only allow rescheduling count_for_process() times.

=item can_reschedule()

Boolean to return true if this pse is allowed to be rescheduled, e.g. it is in a state that allows rescheduling.

=item reschedule()

Performs a best-case rescheduling for whatever ails this pse.  syncs to the database automatically, but does not commit.  On failure, rolls back anything that was synced, and only that.  This does a reasonable job of locking, but lazy committing may lead to deadlocks.

=item alert_informatics()

Returns true if the continued failure of this pse indicates that one should alert informatics.

=item beyond_help()

Returns true if this has failed consistently and is no longer going to be rescheduled

=item refresh()

Update all information for this pse and its job.

=item get_pse(), get_process_step(), get_job()

Just what you expect.  The last is a CSP::Job, not a GSC::PSEJob.

=item pretty()

Returns a pretty string giving you all the information you want.

=item process_job_line ( LINE )

initializes the CSP::Job for this pse from the LINE parameter, which should be the output from bjobs.  This is generally thought to be used internally by the CSP package when bulk loading jobs by calling a general bjobs function.

=item is_problematic()

False if there are no detectable problems here.  Returns a problem string otherwise ('failed', 'lost', 'hanged')

=item is_hanged()

Is  the blade job hung?  True if the blade job has been running more than a process-specific amount of time, defaulting to 4 hours.

=item is_lost()

Is the blade job lost?  True if a blade job does not exist but the database thinks so.

=item is_failed()

Is the pse failed?  Returns false if there is a database job as that suggests it is being debugged.

=item get_fail_logs()

Returns a list of fully qualified paths to the fail logs.

=item current_fail_log()

Returns the most recent fail log.  Because it only scans one directly, significantly faster than get_fail_logs() when one is expected.

=item parse_fail_log( filename => PATH, show => \@, hide => \@, show_tags => \@, hide_tags => \@)

Parses the specified fail log and returns an array of lines that match the expected values.  The default is to show the error tag, which is 'ERROR' or 'DIE' lines.

PARAMS:
 'filename' is fully qualified, and defaults to self->current_fail_log()
 'show' and 'hide' are an array of strings that should match the beginning of lines you cae about
 'show_tags' and 'hide_tags' are more user friendly ways to represent common parse desires.  The following are appropriate tags:
  error, warn, die, sql

=item find_similar_errors( threshold => X, threshold_type => Y)

Search through the error logs for this process and find other pses that have failed with the THRESHOLD-X percent of the same errors.  The threshold_type is whether to evaluate the total or adjusted values.  Uses compare_error_logs.  X should be < 1.


=item compare_error_logs ( log1, log2 )

Compares the two logs, which are already parsed (see parse_fail_logs()), and return an array as follows: 
 0: %similar (how many words matched of the total words). range is 0-1
 1: %similar with adjustments (how many non-numeric words matched of the total words - (words that contain numbers)).  range is 0-1.
 2: total number
 3: adjusted total number

=item compare_errors ( other_csp, PARAMS )

Compares the error logs between the calling CSP::PSE and the parameter CSP::PSE and returns the decimal percent of similarity.  The only recognized parameter right now is threshold_type => 'adjusted'|'real'.  Returns -1 if the word count was too small to realistically evaluate.

=item generic_log ()

Returns a copy of the log file with symbols to suggest 'adjusted out' things for the comparison.

=back

=cut
