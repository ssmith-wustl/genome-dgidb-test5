
package Genome::Model::Tools::LSFSpool;

use strict;
use warnings;
use English;

use Data::Dumper;

use Getopt::Std;
use Cwd 'abs_path';
use File::Basename;
use File::Find::Rule;

use DBI;

use Genome;
use Workflow;

use Genome::Model::Tools::LSFSpool::Suite;
use Genome::Model::Tools::LSFSpool::Cache;
use Genome::Model::Tools::LSFSpool::Error;

use Exception::Class::TryCatch;

use LSF::Job;

my $pid = $$;

class Genome::Model::Tools::LSFSpool {
  is => 'Command',
  has => [
    # FIXME: This should probably be an array of strings.
    # ie. a list of spooldirs.
    spooldir => {
      is => 'String',
      is_input => 1,
      is_output => 1,
      is_optional => 0,
      doc => 'Spool directory to process',
      default => undef,
    },
    configfile => {
      is => 'String',
      is_input => 1,
      is_optional => 0,
      doc => 'Configuration file',
      default => undef,
    },
  ],
};

# -- Subroutines
#
sub create {
  my $class = shift;
  my %params = @_;

  my $self = $class->SUPER::create(%params);

  # Is there a better way to extend a hash of parameters?
  $self->{cache} = Genome::Model::Tools::LSFSpool::Cache->create();

  # This is a bit of a hack to get Cache to use the
  # same logging/debugging as LSFSpool.  Should probably
  # have a Utility library or something that provides logging.
  $self->{cache}->{parent} = $self;

  $self->{config} = {};

  $self->{stopflag} = "LSFSTOP-$pid";
  $self->{debug} = 0;
  $self->{dryrun} = 0;
  $self->{buildonly} = 0;

  $self->{jobids} = ();

  $self->{result} = undef;
  $self->{cachefile} = undef;
  $self->{logdir} = undef;
  $self->{startpos} = undef;
  $self->{bsub} = undef;
  $self->{bkill} = undef;
  $self->{bjobs} = undef;
  $self->{bqueues} = undef;
  $self->{logfile} = undef;
  $self->{logfh} = undef;
  $self->{suite} = undef;
  $self->{dbh} = undef;

  return $self;
}

sub error {
  my $self = shift;
  # At this point, all Errors are the same, fatal.  But we use
  # Exception objects to test them, and potentially have different types
  # of errors, recoverable, fatal, etc.
  Genome::Model::Tools::LSFSpool::Error->throw(error => @_);
}

sub logger {
  # Simple logging where logfile is set during startup
  # to either a file handle or STDOUT.
  my $self = shift;
  my $fh = $self->{logfh};

  $self->error("no logfile defined, run prepare_logger\n")
    if (! defined $fh);

  print $fh localtime() . ": @_";
}

sub local_debug {
  # Simple debugging.
  my $self = shift;
  if ($self->{debug}) {
    $self->logger("DEBUG: @_");
  }
}

sub parsefile {
  # Parse a file name argument and return parameters to be used
  # in an LSF bsub command.
  my $self = shift;
  my $jobname = shift;

  $jobname = abs_path($jobname);
  $self->local_debug("parsefile($jobname)\n");

  # Set the job array number based on the digits in the file name.
  # We do this for convenient accounting.
  my $number;

  # FIXME: this sets number = 1 wrongly in some cases, not sure why yet.
  if ( $jobname =~ m/^.*-(\d+)$/ ) {
    $number = $1;
  } else {
    $self->error("filename does not contain a number\n");
  }

  my $inputfile = basename $jobname; # query file is the file
  my $spooldir = dirname $jobname; # jobname is parent dir

  # This is a single file, thus a single job.  Don't use a square bracket
  # job array, rather just name the job after the file.
  #my $jobarray = basename $spooldir . "\[$number\]";
  my $jobarray = $inputfile;

  $self->local_debug("$spooldir,$inputfile,$jobarray\n");

  return ($spooldir,$inputfile,$jobarray);
}

sub parsedir {
  # Parse a directory name argument and return parameters to be used
  # in an LSF bsub command.
  my $self = shift;
  my $jobname = shift;

  $jobname = abs_path($jobname);
  my $inputfile = basename $jobname . '-\$LSB_JOBINDEX';
  my $spooldir = $jobname;

  my @inputfiles = grep(/$jobname/,$self->findfiles($jobname));
  my $count = grep(!/-output/,@inputfiles);
  my $jobarray = basename $jobname . "\[1-$count\]";

  $self->error("spool $jobname contains no files\n") if ($count == 0);

  return ($spooldir,$inputfile,$jobarray);
}

sub submit_job {
  # Submit an LSF job using bsub.
  # Note that LSF::Job is insufficient for submission as it does not
  # support all the arguments we'd like to use.
  my $self = shift;

  # - If the first argument is a file, create a job array of one value
  # and bsub the one file.
  # - If it's a directory, build an array of N values for all files.
  my $jobname = shift;

  # Optional arguments for wait option -K and priority.
  my $wait = (shift) ? 1 : 0;
  my $prio = (shift) ? 1 : 0;

  $self->local_debug("bsub($jobname,$wait,$prio)\n");

  my $spooldir;
  my $inputfile;
  my $jobarray;

  # Examine our argument and determine job parameters.
  if (-f $jobname) {
    ($spooldir,$inputfile,$jobarray) = $self->parsefile($jobname);
  } elsif (-d $jobname) {
    ($spooldir,$inputfile,$jobarray) = $self->parsedir($jobname);
  } else {
    $self->error("argument is not a file or directory: $jobname\n");
  }

  $self->error("spool contains an invalid file or directory: $jobname\n")
    if (! defined $spooldir);

  chdir $spooldir or $self->error("cannot chdir to $spooldir: $!\n");

  # Note here the use of -E for a "pre-exec" job, where we have bsub re-execute
  # our self to check to see if there's already full output for a particular
  # job index.  This allows for easy re-submission on previous failure.
  my $command = ($wait) ? "$self->{bsub} -K " : "$self->{bsub} ";

  # FIXME: use MAX_USER_PRIO or a configurable
  $command .= ($prio) ? '-sp 300 ' : '';

  # Set -u option for bsub, but be careful, if you're submitting
  # thousands of jobs, your INBOX will become quite full.
  if (exists $self->{config}->{email} and
      length($self->{config}->{email}) > 0) {
    $command .= "-u $self->{config}->{email} ";
  }

  # Append the queue and the jobarray we've constructed.
  $command .= "-q $self->{config}->{queue} -J $jobarray ";

  # LSF post-exec moves output file to destination directory.
  $command .= "-Ep \"mv -f /tmp/$inputfile-output $spooldir/$inputfile-output;\" ";

  # Append logging.
  if ( defined $self->{logdir} ) {
    $command .= '-e ' . $self->{logdir} . "/$jobarray.%I.%J.err ";
    $command .= '-o ' . $self->{logdir} . "/$jobarray.%I.%J.out ";
  }

  # This is the command, as per the Suite called.
  $command .= $self->{suite}->action($spooldir,$inputfile) . " ";

  # Dry run mode shows you what *would* be submitted.
  $self->logger($command . "\n");
  return 0 if ($self->{dryrun});

  # Exec the command and get the jobid.
  open(COMMAND,"$command 2>&1 |") or $self->error("failed to run bsub: $!\n");
  my $output = <COMMAND>;
  close(COMMAND);
  my $rc = $? >> 8;
  if ($rc == 255) {
    $self->logger("bsub exits non-zero: $rc: perhaps queue is closed?\n");
    return -1;
  } elsif ($rc) {
    $self->logger("bsub exits non-zero: $rc\n");
    return -1;
  }
  $output =~ /^.* \<(\d+)\> .*$/;
  my $jobid = $1;

  $self->logger("submitted job id $jobid\n");
  return $jobid;
}

sub check_cwd {
  # The path argument should fit a naming scheme
  # starting with the top level spool name.
  my $self = shift;
  my $jobname = shift;

  $self->local_debug("check_cwd($jobname)\n");
  $self->logger("examine spool directory: $jobname\n");

  my @list = map { basename($_) } $self->findfiles($jobname);
  my $dir = basename $jobname;
  my @oddfiles = grep(!/$dir*/,@list);

  if (scalar @oddfiles != 0) {
    $self->error("spool directory has unexpected files: @oddfiles\n");
  }

  @list = map { basename($_) } $self->finddirs($jobname);
  my @odddirs = grep(!/$dir*/,@list);

  if (scalar @odddirs != 0) {
    $self->error("spool directory has unexpected directories: @odddirs\n");
  }

  return 1;
}

sub check_running {
  # Ask LSF if any jobs named for this spool are running.
  # Both single file or directory are possible.
  my $self = shift;
  my $jobname = shift;
  if (-f $jobname) {
    $jobname =~ /^(.*)-(\d+)$/;
    $jobname = $1;
    my $number = $2;
    $jobname = basename $jobname . "\[$number\]";
  } else {
    $jobname = basename $jobname;
  }
  $self->local_debug("check_running($jobname)\n");
  LSF::Job->PrintOutput(0);
  LSF::Job->PrintError(0);
  my @jobs = LSF::Job->jobs( -J => $jobname );
  $self->logger(scalar @jobs . " " . basename $jobname . " jobs running\n");
  return scalar @jobs;
}

sub finddirs {
  # Find directories, but not deeply.
  my $self = shift;
  my $dir = shift;
  $self->local_debug("finddirs($dir)\n");
  my @result = File::Find::Rule->directory()
                  ->mindepth(1)
                  ->maxdepth(1)
                  ->not_name('.*')
                  ->in($dir);
  $self->local_debug(scalar @result . " directories found\n");
  return @result;
}

sub findfiles {
  # Find files, but not deeply.
  my $self = shift;
  my $dir = shift;
  $self->local_debug("findfiles($dir)\n");
  return ($dir) if (-f $dir);
  my @result = File::Find::Rule->file()
                  ->mindepth(1)
                  ->maxdepth(1)
                  ->not_name('.*')
                  ->in($dir);
  $self->local_debug(scalar @result . " files found\n");
  return @result;
}

sub validate {
  # Look in a spool directory for files and run the is_complete check.  Return
  # a list of incomplete input files.  Note we also want to return some
  # indicator of "No output at all yet":
  #  . no input files, nothing to do, return (-1,())
  #  . no output at all, return (0,())
  #  . some output is partial, return (0,@list)
  #  . complete output is present, if @list is empty
  my $self = shift;
  my $spooldir = shift;

  $self->local_debug("validate($spooldir)\n");

  # Validate that all output files are present and complete.
  my @errors;
  my @infiles;

  # Validate files on the filesystem.
  # Make a list of input files:
  @infiles = (grep(!/-output/,$self->findfiles($spooldir)));

  # If there are no files, there's nothing to do.
  if (scalar @infiles == 0) {
    $self->logger("No files in spool $spooldir, nothing to do\n");
    return (-1,());
  }

  # For each input file, examine output file for "completeness".
  foreach my $infile (@infiles) {
    next unless ($infile);
    $self->local_debug("$infile\n");
    push @errors, basename $infile if (! $self->{suite}->is_complete($infile));
  }

  # If we have zero output, we want a job array for the whole dir.
  if (scalar @infiles == scalar @errors) {
    $self->logger("spool has no complete files yet\n");
    return (0,());
  }

  # Report errors and incompletenesses.
  $self->local_debug(scalar @errors . " incomplete files\n");

  # If @errors is empty, output is complete.
  return (1,()) if (scalar @errors == 0);

  # If @errors is non-empty (yet also != @infiles) then we're partially complete.
  return (0,@errors);
}

sub waitforjobs {
  my $self = shift;
  # Wait for an LSF job to complete.
  my $sleepval = $self->{config}->{sleepval};
  my $jobname = shift;
  $self->logger("waiting for jobs: $jobname\n");
  while (1) {
    my $count = $self->check_running($jobname);
    last if (! $count);
    sleep $sleepval;
  }
}

sub check_churn {
  # Check churn rate, and sleep if we're churning.
  # Churn is when we're examinining the same job too quickly.
  my $self = shift;
  my $dir = shift;
  $self->local_debug("check_churn($dir)\n");
  my @result = $self->{cache}->fetch($dir,'time');
  my $lastcheck = $result[0];
  return 0 if (! defined $lastcheck);
  $self->local_debug("last check $lastcheck\n");
  my $check = time() - $lastcheck;
  if ( $check < $self->{config}->{churnrate} ) {
    $self->local_debug("$check < $self->{config}->{churnrate} = churning\n");
    return 1;
  }
  return 0;
}

sub run_bqueues {
  # Use bqueues to determine queue fullness.
  my $self = shift;
  my $command = "$self->{bqueues} $self->{config}->{queue}";
  my $line = "?";

  $self->local_debug("run_bqueues($command)\n");

  open(COMMAND,"$command 2>&1 |") or $self->error("failed to run bqueues: $!\n");
  while (<COMMAND>) {
    $line = $_ if (/^$self->{config}->{queue}/);
  }
  close(COMMAND);
  my $rc = $? >> 8;

  # If bqueues can't be run for some reason, return uncertain.
  # Do this line check because we have anecdotes of bqueues running
  # and exiting 0 but not returning the output here.
  if ($line eq "?") {
    $self->local_debug("bqueues error: $line\n");
    return -1;
  }

  my @toks = split(/\s+/,$line);
  my $njobs = $toks[7];
  return $njobs;
}

sub run_bjobs {
  my $self = shift;
  my $command = "$self->{bjobs} -u $self->{config}-{user} -q $self->{config}->{queue}";
  my $njobs = 0;

  $self->local_debug("run_bjobs($command)\n");
  open(COMMAND,"$command 2>&1 |") or $self->error("failed to run bqueues: $!\n");
  while (<COMMAND>) {
    # skip the header
    next if (/^JOBID/);
    $njobs++;
  }
  close(COMMAND);
  my $rc = $? >> 8;

  if ($rc) {
    return -1;
  }

  return $njobs;
}

sub check_queue {
  # Check how many jobs are running.
  # Return values are:
  # 1   Queue above queueceiling
  # 0   Queue below queuefloor
  # -1  Queue between floor and ceiling
  my $self = shift;
  my $njobs;

  if ( exists $self->{config}->{user} ) {
    $njobs = $self->run_bjobs();
  } else {
    $njobs = $self->run_bqueues();
  }

  $self->local_debug("queue: $self->{config}->{queue} $njobs\n");
  return 1 if ( defined $njobs and $njobs > $self->{config}->{queueceiling} );
  return 0 if ( defined $njobs and $njobs < $self->{config}->{queuefloor} );
  return -1; # was full, not yet empty enough
}

sub process_dir {
  # Conditionally bsub a directory.
  my $self = shift;
  my $dir = shift;

  $self->local_debug("process_dir($dir)\n");

  # Check running first, don't update anything if jobs are running.
  # Note we may have to check running again later...
  if ($self->check_running($dir) > 0) {
    $self->logger("skipping active spool " . basename $dir . "\n");
    return 0;
  }

  # Ignore completed spools.
  # Check completeness from the cache first...
  my @result = $self->{cache}->fetch($dir,'complete');
  my $complete = $result[0];
  return 0 if (defined $complete and $complete == 1);

  my %infiles;
  my @files = $self->{cache}->fetch($dir,'files');
  if (defined $files[0] and scalar @files > 0 and $files[0] =~ /^\w+/ ) {
    # If we last cached incomplete 'files', recheck them.
    $complete = 0;
    my @infiles = split(",",$files[0]);
    foreach my $file (@infiles) {
      $self->local_debug("validate $file\n");
      $infiles{$file} = 1 if ($self->{suite}->is_complete($file));
    }
    $complete = 1 if (scalar keys %infiles == 0);
    @files = keys %infiles;
  } else {
    # Else, check whole dir completeness from filesystem...
    ($complete,@files) = $self->validate($dir);
  }
  $self->local_debug("incomplete files: " . join(",",@files) . "\n");
  $self->{cache}->add($dir,'files',join(",",@files));

  # NOTE: We can mark a spool complete while a job is running here.
  if ($complete == -1) {
    # Don't update cache if over the retry limit.
    $self->logger("over retry limit $dir\n");
    return 0;
  } elsif ($complete == 1) {
    # Filesystem says this $dir is complete, mark it so.
    $self->logger("$dir complete\n");
    $self->{cache}->add($dir,'complete',1);
    return 0;
  } else {
    $self->logger("$dir incomplete\n");
    $self->{cache}->add($dir,'complete',0);
  }

  # Conditionally return right after completeness check
  # if we only want the cache built.
  return 0 if ($self->{buildonly});

  # Check churn before check running, before bsub...
  # Note we might "churn" here, if the queue is below
  # the ceiling, but has jobs running for incomplete spools.
  # This would happen if we kill this process, but leave jobs
  # running then restart.
  my $churning = $self->check_churn($dir);
  if ($churning) {
    $self->logger("sleeping $self->{config}->{sleepval} until next check\n");
    sleep $self->{config}->{sleepval};
    # Return so as to recheck completeness (at the top of this subroutine).
    return 0;
  }

  # Update the time of this check, do so after churn check.
  $self->{cache}->add($dir,'time',time());

  # Check running before queue full check and bsub, after check_churn sleep...
  # Ignore currently running spools.
  if ($self->check_running($dir) > 0) {
    $self->logger("skipping active spool " . basename $dir . "\n");
    $self->{cache}->add($dir,'time',time());
    return 0;
  }

  # Check queue full before retry limit and bsub...
  # When queue is full, sleep until we hit queuefloor.
  my $full = $self->check_queue();
  if ($full == 1) {
    while ($full != 0) {
      $self->logger("sleeping $self->{config}->{sleepval} until queue empties\n");
      sleep $self->{config}->{sleepval};
      $full = $self->check_queue();
    }
    # Return so as to recheck completeness (at the top of this subroutine).
    return 0;
  }

  # Check retry limit before bsub...
  # If we set a retry limit, respect it.
  @result = $self->{cache}->fetch($dir,'count');
  my $count = $result[0];
  if ($self->{config}->{lsf_tries} > 0 and
      defined $count and
      $count >= $self->{config}->{lsf_tries}) {
    $self->{cache}->add($dir,'complete',-1);
    $self->logger("over the retry limit $self->{config}->{lsf_tries} for " . basename $dir . ", giving up\n");
    return 0;
  }

  # Check a stop flag that would halt submission...
  if ( exists $self->{config}->{stopflag} and -f $self->{config}->{stopflag} ) {
    $self->{cache}->add($dir,'time',time());
    $self->logger("Stop flag is set, skipping bsub\n");
    return 0;
  }

  # Bsub...
  my $jobid = 0;
  if (scalar @files) {
    # Resubmit just the failures from the last run.
    foreach my $incomplete (@files) {
      # Note we store based on $dir, but we may submit a subdir $incomplete,
      # So we could have N jobids for a $dir but only one place to store one.
      $jobid = $self->submit_job("$dir/$incomplete");
    }
  } else {
    # If specific files weren't present, do the whole dir.
    $jobid = $self->submit_job($dir);
  }

  # We keep a list of jobids we've started.
  if ($jobid) {
    push @{$self->{jobids}}, $jobid;
  }

  $self->{cache}->add($dir,'time',time());
  $self->{cache}->counter($dir);

  return 0;
}

sub process_cache {
  # Traverse the cache, submitting items as we go.

  my $self = shift;

  $self->local_debug("process_cache()\n");

  while (1) {

    # Sorted list of incomplete spool dirs.
    my @dirlist = sort { ($a =~ /^.*-(\d+)$/)[0] <=> ($b =~ /^.*-(\d+)/)[0] } $self->{cache}->fetch_complete(0);

    # We're done when there's nothing left to do.
    if (scalar @dirlist == 0) {
      $self->logger("processing complete\n");
      return 0;
    }

    for my $dir ( @dirlist ) {
      $self->local_debug("check cached dir $dir\n");
      $self->process_dir($dir);
    }
  }
}

sub build_cache {
  # Traverse spoolname and build a cache representing how much
  # work has been done.

  my $self = shift;
  my $spoolname = shift;

  $self->local_debug("build($spoolname)\n");

  if (! defined $self->{cachefile}) {
    $self->{cachefile} = $spoolname . ".cache";
  }

  # Make a log dir as a sibling to the cache file.
  $self->{logdir} = $spoolname . ".logs";
  if (! -d $self->{logdir}) {
    mkdir $self->{logdir} or
      $self->error("cannot create log directory $self->{logdir}: $!\n");
  }

  $self->{cache}->prep();

  # If this is a spool dir of dirs, process the dirs.
  my @dirlist = $self->finddirs($spoolname);
  @dirlist = sort { ($a =~ /^.*-(\d+)$/)[0] <=> ($b =~ /^.*-(\d+)/)[0] } @dirlist;

  # If this is a spool dir of files, process self.
  push @dirlist,$spoolname if (scalar @dirlist == 0);

  # Sentinel used to watch for startpos, if defined.
  my $startflag = 0;

  # For each dir in the spool prep a cache entry.
  for (my $idx = 0; $idx <= $#dirlist; $idx++) {

    my $dir = $dirlist[$idx];
    next if (!$dir);

    # If we set starting position, check it.
    if (defined $self->{startpos} and !$startflag) {
       my $d = basename $dir;
       $startflag = 1 if ($d eq $self->{startpos});
       next if ($startflag != 1);
    }

    $self->process_dir($dir);
    delete $dirlist[$idx];
  }
  $self->local_debug("build($spoolname) complete\n");
  return 0;
}

sub is_valid {
  # This subroutine handles the CLI invocation of validate().

  my $self = shift;
  my $spooldir = shift;
  my $retval;
  $self->local_debug("is_valid($spooldir)\n");

  my ($complete,@files) = $self->validate($spooldir);

  if ($complete == -1) {
    # @files is undef
    $self->logger("spool $spooldir is a spool of spools, validate sub-spools instead\n");
    $retval = undef;
  } elsif ($complete) {
    # 99 means all files validated
    $self->logger("spool $spooldir is complete\n");
    $retval = 99;
  } else {
    $self->logger("spool $spooldir is incomplete\n");
    foreach my $file (@files) {
      $self->local_debug("\t$file\n");
    }
    $retval = 0;
  }

  return 0 if (!defined $retval);

  # Update cache if specifically given on CLI.
  if (defined $self->{cachefile}) {
    $self->{cache}->prep($self->{cachefile});
    $self->{cache}->add($spooldir,'files',join(",",@files));
    if ($retval == 99) {
      $self->{cache}->add($spooldir,'complete',1);
    } else {
      $self->{cache}->add($spooldir,'complete',0);
    }
  }
  return $retval;
}

sub usage {
  my $self = shift;
  print "lsf_spool [-hbcprsvVw] [-i cachefile] [-S subdir] [-C configfile] [-l logfile] <batch_file|spool_directory>

Usage:

  -C    specify Config file name (eg: ./lsf_spool.cfg)
  -b    build a cache of spools (bsub along the way unless dryrun mode)
  -c    check the status of current query (file or dir)
  -h    this helpful message
  -i    for a spool dir, use this named cache file
  -l    specify log file (STDOUT by default)
  -n    dry run mode, do all except submission.
  -p    process all queries given (file or dir)
  -s    submit the given query (file or dir)
  -S    for a spool dir, start processing at this subdir
  -r    re-submit the given query (file or dir) (MAX_USER_PRIO)
  -v    validate the given query (file or dir)
  -w    wait for the given query to finish

";
 return 1;
}

sub check_args {
  # Sanity check command line arguments.
  my $self = shift;
  my @args = @_;

  $self->local_debug("check_args()\n");

  my $files = 0;
  my $dirs = 0;

  $self->error("no spool argument given\n")
    if ($#args == -1);

  # Arguments must be either all dirs or all files.
  foreach my $arg (@args) {
    $self->error("no such file or directory $arg\n") if (! -e $arg);
    $files = 1 if (-f $arg);
    $dirs = 1 if (-d $arg);
  }

  $self->error("arguments must be all files or all directories, not a mix\n") if ($files and $dirs);

  my @list = @args;

  # Canonicalize paths.
  @list = map { abs_path($_) } @list;

  # Sanity check spool dirs.
  if ($dirs) {
    foreach my $arg (@list) {
      $self->check_cwd($arg);
    }
  }

  # If a starting position (subdir) is given, validate it.
  if (defined $self->{startpos}) {
    $self->error("starting position only valid with a single spool dir\n") 
      if (scalar @list != 1);
    $self->error("starting position only valid with spool dir, not a batch file: $list[0]\n") 
      if (-f $list[0]);
    $self->error("starting directory not found in spool: $list[0]/$self->{startpos}\n") 
      if (! -d "$list[0]/$self->{startpos}");

    $self->{startpos} = Cwd::abs_path($list[0] . "/" . $self->{startpos});
    $self->{startpos} = basename $self->{startpos};
    $self->local_debug("Start spool $list[0] with sub-directory $self->{startpos}\n");
  }

  $self->error("empty argument list\n") if (scalar @list == 0);
  return @list;
}

sub read_config {
  # Read a simple configuration file that contains a hash object
  # and subroutines.
  my $self = shift;

  # YAML has Load
  use YAML::XS;
  # Slurp has read_file
  use File::Slurp;

  $self->error("please specify a config file with the -C option\n")
    if (! defined $self->{configfile});

  my $configfile = abs_path($self->{configfile});

  try eval {
    $self->{config} = Load scalar read_file($configfile);
  };
  if (catch my $err) {
    $self->error("error loading config file '$configfile': $err->{message}\n");
  }

  # Validate configuration.
  my @required = ('suite', 'queue', 'sleepval', 'queueceiling',
                   'queuefloor', 'churnrate', 'lsf_tries', 'db_tries' );
  my $req;
  foreach $req (@required) {
    $self->error("configuration is missing required parameter '$req'\n")
      if (! exists $self->{config}->{$req});
  }
  @required = ('name', 'parameters',);
  foreach $req (@required) {
    $self->error("configuration is missing required parameter '$req'\n")
      if (! exists $self->{config}->{suite}->{$req});
  }
}

sub activate_suite {
  # Now activate the configured suite.
  my $self = shift;
  my $class = $self->{config}->{suite}->{name};

  $self->local_debug("Activating suite: $class\n");
  $self->{suite} = Genome::Model::Tools::LSFSpool::Suite->create($class,$self);

  $self->error("configured suite has no method 'is_complete'\n")
    if ( ! $self->{suite}->can( "is_complete" ) );
}

sub prepare_logger {
  # Set the file handle for the log.
  # Use logfile in .cfg if not given on CLI.
  my $self = shift;
  # Config may have logfile
  if (defined $self->{config}->{logfile}) {
    $self->{logfile} = $self->{config}->{logfile};
  }
  # Command line overrides config file
  if (defined $self->{logfile}) {
    $self->{logfile} = $self->{logfile};
  }
  # Open logfile or STDOUT.
  if (defined $self->{logfile}) {
    open(LOGFILE,">>$self->{logfile}") or
      $self->error("failed to open log file $self->{logfile}: $!\n");
    $self->{logfh} = \*LOGFILE;
  } else {
    $self->{logfh} = \*STDOUT;
  }
}

sub find_progs {
  # Find ancillary software.
  my $self = shift;

  $self->local_debug("find_progs()\n");

  # We shell out to bsub because LSF::Jobs is insufficient.
  my $bsub = `which bsub 2>/dev/null`;
  chomp $bsub;
  $self->error("cannot find bsub in PATH\n")
    if (length "$bsub" == 0);
  $self->{bsub} = $bsub;

  # We shell out to bkill because LSF::Jobs is insufficient.
  my $bkill = `which bkill 2>/dev/null`;
  chomp $bkill;
  $self->error("cannot find bkill in PATH\n")
    if (length "$bkill" == 0);
  $self->{bkill} = $bkill;

  # We shell out to bqueues.
  my $bqueues = `which bqueues 2>/dev/null`;
  chomp $bqueues;
  $self->error("cannot find bqueues in PATH\n")
    if (length "$bqueues" == 0);
  $self->{bqueues} = $bqueues;

  # We may shell out to bjobs.
  my $bjobs = `which bjobs 2>/dev/null`;
  chomp $bjobs;
  $self->error("cannot find bjobs in PATH\n")
    if (length "$bjobs" == 0);
  $self->{bjobs} = $bjobs;

  return 0;
}

# Signal handling similar to Workflow, but without the use of Guard
sub set_signals {
  my $self = shift;
  $self->local_debug("set_signals()\n");
  my $cb = sub {
    # FIXME: Is this safe in a signal handler?  Callbacks are supposed to be
    # fast and short.
    $self->logger("signalled exit, kill all jobs\n");
    my $command = $self->{bkill} . " " . join(' ',@{$self->{jobids}}) . "\n";
    $self->local_debug($command);
    system($command);
    exit;
  };
  foreach my $sig ('HUP','INT','TERM') {
    $SIG{$sig} = $cb;
  }
}

sub execute {
  my $self = shift;

  # spooldir gets set on create() via a Workflow process
  $self->error("no spooldir provided upon create()\n")
    if (! defined $self->{spooldir});

  my @args = ($self->{spooldir});

  $self->read_config();
  $self->prepare_logger();
  $self->activate_suite();
  $self->find_progs();

  my @dirs = $self->check_args(@args);

  $self->set_signals;

  foreach my $spooldir (@dirs) {
    $self->build_cache($spooldir);
    $self->{result} = $self->process_cache();
  }

  return 0;
}

sub main {

  my $self = shift;
  @ARGV = @_ if (@_);
  my %opts;

  getopts("C:bcdhi:l:nprsS:vVw",\%opts) or
    $self->error("Error parsing options\n");

  if ($opts{'h'}) {
    $self->usage();
    return 0;
  }

  $self->{debug} = (delete $opts{'d'}) ? 1 : 0;
  $self->{dryrun} = (delete $opts{'n'}) ? 1 : 0;
  $self->{cachefile} = (delete $opts{'i'});
  delete $opts{'i'};
  $self->{logfile} = ($opts{'l'});
  delete $opts{'l'};
  $self->{startpos} = ($opts{'S'});
  delete $opts{'S'};
  $self->{configfile} = $opts{'C'} if ($opts{'C'});
  delete $opts{'C'};

  # Read configuration file, may have logfile setting in it.
  $self->read_config();

  # Open log file as soon as we have options parsed.
  $self->prepare_logger();

  if (scalar keys(%opts) > 1) {
    $self->logger("select only one action: " . join(" ", keys %opts) . "\n\n");
    $self->usage();
    return 1;
  }

  # Activate the specified Suite, which defines what actions we're
  # going to submit to LSF and how we identify them as "complete".
  $self->activate_suite();

  # Find required programs.
  $self->find_progs();

  # Ensure args are proper.
  my @joblist = $self->check_args(@ARGV);

  my $rc = 0;
  foreach my $job (@joblist) {

    if ($opts{'b'}) {
      $self->{buildonly} = 1;
      $rc = $self->build_cache($job);
      $self->logger("added $job to cache\n");
    } elsif ($opts{'c'}) {
      $rc = $self->check_running($job);
    } elsif ($opts{'r'}) {
      $rc = $self->submit_job($job,0,1);
    } elsif ($opts{'s'}) {
      $rc = $self->submit_job($job);
    } elsif ($opts{'w'}) {
      $rc = $self->waitforjobs($job);
    } elsif ($opts{'p'}) {
      if (! -d $job) {
        $self->error("consider -s option with files, not -p\n");
      }
      $self->logger("begin processing $job\n");
      $rc = $self->build_cache($job);
      $rc = $self->process_cache();
      $self->logger("processing complete $job\n");
    } elsif ($opts{'v'}) {
      $rc = $self->is_valid($job);
    } else {
      if (scalar keys %opts) {
        $self->usage();
        $self->error("unknown option: " . join(" ", keys %opts));
      } else {
        $self->usage();
        $self->error("no action specified\n\n");
      }
    }
  }
  close($self->{logfh})
    if ($self->{logfh} != \*STDOUT);

  $self->{dbh}->disconnect() if (defined $self->{dbh});

  # Note this only returns the *last* return code...
  # This isn't very robust, but is better than nothing for now.
  return $rc;
}

# Subroutines providing usage documentation in the Genome Model Way.
sub help_brief {
  "LSFSpool manages submission of LSF jobs via a spool of input data.",
}

sub help_synopsis {
  my $self = shift;
  return <<"EOS"
Intended to be used within a Workflow. eg: blastx-spool:

LSFSpool [-hbcprsvVw] [-i cachefile] [-S subdir] [-C configfile] [-l logfile] <batch_file|spool_directory>
EOS
}

sub help_detail {
  return <<EOS
LSFSpool is intended to be part of a Workflow.  See blastx-spool for an example.
EOS
}

1;
__END__

=pod

=head1 NAME

Genome::Model::Tools::LSFSpool - Manage a lsf job spool

=head1 SYNOPSIS

  lsf_spool [-hbcprsvVw] [-i cachefile] [-S subdir] [-C configfile] [-l logfile] <batch_file|spool_directory>

=head1 OPTIONS

  -C    specify Config file name (eg: ./lsf_spool.cfg)
  -b    build a cache of spools (don't bsub along the way)
  -c    check the status of current query (file or dir)
  -h    this helpful message
  -i    for a spool dir, use this named cache file
  -l    specify log file (STDOUT by default)
  -n    dry run mode, do all except submission.
  -p    process all queries given (file or dir)
  -s    bsub the given query (file or dir)
  -S    for a spool dir, start processing at this subdir
  -r    re-bsub the given query (file or dir) (MAX_USER_PRIO)
  -v    validate the given query (file or dir)
  -w    wait for the given query to finish

=head1 DESCRIPTION

This module is for managing a spool of files to be processed via LSF.

Given a set of input files A, a program B, and a "completeness condition",
this program will attempt to submit jobs to LSF in such a way as to 
satisfy the following conditions:

  - Keep trying to run B on A until "complete".
  - Keep the LSF queue "full" but not "too full".
  - Don't resubmit jobs that keep failing, ie. "churn".

=head1 CONFIGURATION

The file B<lsf_spool.cfg>, residing normally in B<~/.lsf_spool>, contains
a variety of configuration parameters.

The configuration file is YAML formatted file containing the table of options.

  suite:
    name: BLAST
    parameters: -db /opt/nr/nr-20100424_0235/nr -matrix BLOSUM62 -evalue 100 -word_size 6 -threshold 23 -num_descriptions 10 -num_alignments 10 -lcase_masking -seg yes -soft_masking true -window_size 0
  queue: backfill
  sleepval: 60
  queueceiling: 10000
  queuefloor: 1000
  churnrate: 30
  lsf_tries: 2
  db_tries: 1
  email: user@genome.wustl.edu
  user:  user

  - suite
    + name       : The certified program to run (eg. BLAST)
    + parameters : Parameters for the program
  - queue        : The LSF queue to submit to.
  - user         : The LSF user, only count this user's jobs.
  - sleepval     : Seconds to sleep between status checks.
  - churnrate    : Seconds before which a job should not be resubmitted.
  - queueceiling : Number of jobs representing a "full" queue.
  - queuefloor   : Number of jobs representing an "empty" queue.
  - email         : Email address for LSF to email notifications to (NOISY!).
  - lsf_tries    : Number of repeat attempts at a job, 0 means infinite.
  - db_tries     : Number of times to retry DB connection.

Be careful with the B<email> option.  B<Millions of jobs make millions of emails.>

=head1 EXAMPLES

Add the B<-d> option to enable debugging for any other option.
Add the B<-l> option to log to a named log file.

For example, given a FASTA file s_1_1_for_bwa_input.pair_a with millions
of DNA sequences, break this up into a spool of batch files with some set
parameters, usually chosen to satisfy LSF job parameters.

  # batch_fasta --reads 500 --batches 100 s_1_1_for_bwa_input.pair_a

The above produces a directory structure like:

  ./spool-s_1_1_for_bwa_input.pair_a
  ./spool-s_1_1_for_bwa_input.pair_a/spool-s_1_1_for_bwa_input.pair_a-1
  ./spool-s_1_1_for_bwa_input.pair_a/spool-s_1_1_for_bwa_input.pair_a-2
  ./spool-s_1_1_for_bwa_input.pair_a/spool-s_1_1_for_bwa_input.pair_a-3
  ./spool-s_1_1_for_bwa_input.pair_a/spool-s_1_1_for_bwa_input.pair_a-4
  ...
  ./spool-s_1_1_for_bwa_input.pair_a/spool-s_1_1_for_bwa_input.pair_a-N

Now this directory is the "spooldir":

  ./spool-s_1_1_for_bwa_input.pair_a

Process the entire spool via:

  # lsf_spool -l ./spool-s_1_1_for_bwa_input.pair_a.log \
    -p ./spool-s_1_1_for_bwa_input.pair_a

Some other examples:

  # lsf_spool -d -s spooldir

Submit each file in B<spooldir> to LSF by running B<program> with B<parameters>.

  # lsf_spool -d -r spooldir

Retry the spooldir.  This is the same as B<-s> but with a higher LSF priority
(300).

  # lsf_spool -d -r spooldir/batchfile

Resubmit just one batchfile within the spooldir.

  # lsf_spool -d -p spooldir

Process the spooldir, submitting each job within it including subdirectories (1
level of depth), until they are all complete.  This will try B<lsf_tries> times
to run B<program> on B<inputfile> from spooldir, and will keep running until
the spooldir has been completely processed.

  # lsf_spool -d -p spooldir/batchfile

Process a single batchfile in the spooldir, retrying it until it is done.

  # lsf_spool -d -w spooldir

Wait for any running jobs on spooldir.

  # lsf_spool -d -c spooldir

Check spooldir for any running jobs.

  # lsf_spool -d -v spooldir

Validate each file in spooldir with the is_complete() check.  This will display
any incomplete files.

=head1 CLASS METHODS

=over

=item create

Instantiates the class.

=item local_debug

Logs a line if debug is true.

=item logger

Logs a line.

=item parsefile

Parses a batch file name and returns the proper spool directory, input file
name, and job array string.

=item parsedir

Parses a spool directory name and returns the proper spool directory, input file
name, and job array string.

=item submit_job

Calls submit_job to run a command.

=item check_cwd

Examines the contents of a spool directory and performs sanity checks.  A spool
directory should contain all files or all directories, and each of these should
have a name that fits the regex /^\w+-\d+-\d+/, as produced by the
batch_fasta.pl program, for example.

=item check_running

Determine if LSF jobs are currently running for the spool directory.

=item finddirs

Find (not deeply) directories in a path.

=item findfiles

Find (not deeply) files in a path.

=item validate

Validate outptu files in a spool directory by calling a Suite's "is_complete"
method on each one.

=item waitforjobs

Check for running LSF jobs and wait for them to complete.

=item check_churn

Check the last check time for a spool directory and indicate if it was checked
"too soon" for another check.

=item check_queue

Check the LSF queue for the named spool and determine if it is "full"
or empty enough for more work.

  1   Queue above queueceiling
  0   Queue below queuefloor
 -1   Queue between floor and ceiling

=item process_dir

Process the spool directory, submitting jobs for incomplete input files.

=item process_cache

Process cached spool directories, submitting jobs for incomplete input files.

=item build_cache

Build a cache of completed work for a given spool directory.  This is an SQLite
file in the home directory (.lsf_spool).

=item is_valid

Check a file for completeness.

=item usage

Print the program's usage summary.

=item check_args

Sanity check command line arguments.

=item read_config

Read the YAML formatted configuration file.

=item activate_suite

Activate the named Suite, makeing "action" and "is_complete" available for the
named command.

=item prepare_logger

Prepare a log file or STDOUT for use with logger() and debug().

=item find_progs

Find LSF external programs.

=item main

The main program body for use as a CLI tool.

=back

=head1 AUTHOR

Matthew Callaway

=head1 COPYRIGHT

Copyright (C) 2010 Washington University Genome Center

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 KNOWN ISSUES

- Should call out to things like basename less frequently.

=head1 HISTORY

Try/catch/finally originally provided by Error::Simple, which recommends using
something else, it's deprecated.  Had some issues where return() did not
properly return from subroutines using Error::Simple.  Considered Try::Tiny,
but it doesn't support return() or throw().  Considered TryCatch but also
doesn't have throw().  Settled on Exception::Class and
Exception::Class::TryCatch.  Definitely not obvious how to use it.  Implement
Errors class with a throw().  Basically this is eval { } and $@ but offers much
more flexibility and robustness.

