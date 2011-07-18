package Genome::Sys;

# Short Term: shellcmd() should probably be rewritten, it does not correctly use $! after the system call.  Would also be nice if
# it could support IO wrapping of command being executed.  shellcmd() might be better off in its own module, since its not strictly
# a filesystem function.

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Carp;
require IO::Dir;
require IO::File;
require File::Basename;
require File::Path;
require File::Copy;
require Genome::Utility::Text;
use Digest::MD5;
use Sys::Hostname;
use File::Find;

require MIME::Lite;

# this helps us clean-up locks

my %SYMLINKS_TO_REMOVE;

# disk usage management

sub disk_usage_for_path { 
    my $self = shift;
    my $path = shift;

    unless (-d $path) {
        $self->error_message("Path $path does not exist!");
        return;
    }

    return unless -d $path;
    my $cmd = "du -sk $path 2>&1";
    my $du_output = qx{$cmd};
    my $kb_used = ( split( ' ', $du_output, 2 ) )[0];
    unless (Scalar::Util::looks_like_number($kb_used)) {
        $self->error_message("du output is not a number: $kb_used");
        return;
    }

    return $kb_used;
}


#< Files >#

sub read_file {
    my ($self, $fname) = @_;
    my $fh = $self->open_file_for_reading($fname);
    Carp::croak "Failed to open file $fname! " . $self->error_message() . ": $!" unless $fh;
    if (wantarray) {
        my @lines = $fh->getlines;
        return @lines;
    }
    else { 
        my $text = do { local( $/ ) ; <$fh> } ;  # slurp mode
        return $text;
    }
}

sub write_file {
    my ($self, $fname, @content) = @_;
    my $fh = $self->open_file_for_writing($fname);
    Carp::croak "Failed to open file $fname! " . $self->error_message() . ": $!" unless $fh;
    for (@content) {
        $fh->print($_) or Carp::croak "Failed to write to file $fname! $!";
    }
    $fh->close or Carp::croak "Failed to close file $fname! $!";
    return $fname;
}

sub diff_text_vs_text {
    my ($self,$t1,$t2) = @_;
    my $p1 = $self->create_temp_file_path();
    $self->write_file($p1, $t1);
    my $p2 = $self->create_temp_file_path();
    $self->write_file($p2, $t2);
    
    return $self->diff_file_vs_file($p1, $p2);
}

sub diff_file_vs_text {
    my ($self,$f1,$t2) = @_;
    my $p2 = $self->create_temp_file_path();
    $self->write_file($p2, $t2);
    
    return $self->diff_file_vs_file($f1, $p2);
}

sub diff_file_vs_file {
    my ($self,$f1,$f2) = @_;
    
    my $diff_fh = IO::File->new("sdiff -s $f1 $f2 2>&1 |");
    unless ($diff_fh) {
        Carp::croak("Can't run 'sdiff -s $f1 $f2' for diff_file_vs_file(): $!");
    }
    my $diff_output = do { local( $/ ) ; <$diff_fh> };
    return $diff_output;
}

sub open_file_for_appending {
    my ($self, $file) = @_;

    unless ( defined $file ) {
        Carp::croak("No append file given");
    }

    if ( -d $file ) {
        Carp::croak("Append file ($file) is a directory and cannot be opend as a file");
    }
    
    my ($name, $dir) = File::Basename::fileparse($file);
    unless ( $dir ) {
        Carp::croak("Can't determine directory from append file ($file)");
    }
    
    unless ( -w $dir ) { 
        Carp::croak("Do not have WRITE access to directory ($dir) for append file ($name)");
    }

    return $self->_open_file($file, 'a');
}

sub validate_file_for_writing {
    my ($self, $file) = @_;

    unless ( defined $file ) {
        Carp::croak("Can't validate_file_for_writing: No file given");
    }

    if ($file eq '-') {
        return 1;
    }

    if ( -s $file ) {
        Carp::croak("Can't validate_file_for_writing: File ($file) has non-zero size, refusing to write to it");
    }

    # FIXME there is a race condition where the path could go away or become non-writable
    # between the time this method returns and the time we actually try opening the file
    # for writing

    # validate_file_for_writing_overwrite throws its own exceptions if there are problems
    return $self->validate_file_for_writing_overwrite($file);
}


sub validate_file_for_writing_overwrite {
    my ($self, $file) = @_;

    unless ( defined $file ) {
        Carp::croak("Can't validate_file_for_writing_overwrite: No file given");
    }

    my ($name, $dir) = File::Basename::fileparse($file);
    unless ( $dir ) {
        Carp::croak("Can't validate_file_for_writing_overwrite: Can't determine directory from pathname ($file)");
    }
    
    unless ( -w $dir ) { 
        Carp::croak("Can't validate_file_for_writing_overwrite: Do not have WRITE access to directory ($dir) to create file ($name)");
    }

    # FIXME same problem with the race condition as noted at the end of validate_file_for_writing()
    return 1;
}

sub bzip {
    my $self = shift;
    my $file = shift;

    # validate_file_for_reading throws its own exceptions when there are problems
    $self->validate_file_for_reading($file)
        or return;

    my $bzip_cmd = "bzip2 -z $file";
    my $result_file = $file.".bz2";
    # shellcmd throws its own exceptions when there are problems, including checking existence of output file
    $self->shellcmd(cmd=>$bzip_cmd, 
                    output_files=>[$result_file]
                    );

    return $result_file;

}

sub bunzip {
    my $self = shift;
    my $file = shift;

    $self->validate_file_for_reading($file)
        or return;

    if ($file=~m/\.bz2$/) {  

        #the -k option will keep the bzip file around
        my $bzip_cmd = "bzip2 -dk $file";

        #get the unzipped file name by removing the .bz2 extension.
        $file=~m/(\S+).bz2/;
        my $result_file = $1;

        $self->shellcmd(cmd=>$bzip_cmd, 
                        output_files=>[$result_file],
                        );

        return $result_file;

    } else {
        Carp::croak("Input file ($file) does not have .bz2 extension.  Not unzipping.");
    } 

}

sub open_file_for_writing {
    my ($self, $file) = @_;

    $self->validate_file_for_writing($file)
        or return;

    if (-e $file) {
        unless (unlink $file) {
            Carp::croak("Can't unlink $file: $!");
        }
    }
    
    return $self->_open_file($file, 'w');
}

sub copy_file {
    my ($self, $file, $dest) = @_;

    $self->status_message("copying $file to $dest...\n");

    $self->validate_file_for_reading($file)
        or Carp::croak("Cannot open input file ($file) for reading!");

    $self->validate_file_for_writing($dest)
        or Carp::croak("Cannot open output file ($dest) for writing!");

    # Note: since the file is validate_file_for_reading, and the dest is validate_file_for_writing, 
    #  the files can never be exactly the same.
    
    unless ( File::Copy::copy($file, $dest) ) {
        Carp::croak("Can't copy $file to $dest: $!");
    }
    
    return 1;
}

sub copy_directory {
    my ($self, $source, $dest) = @_;

    $self->status_message("copying directory: $source to $dest...\n");

    $self->shellcmd(
        cmd => "cp -r '$source' '$dest'",
        input_directories => [$source],
        output_directories => [$dest],
    );
    
    return 1;
}


#< Dirs >#
sub validate_existing_directory {
    my ($self, $directory) = @_;

    unless ( defined $directory ) {
        Carp::croak("Can't validate_existing_directory: No directory given");
    }

    unless ( -e $directory ) {
        Carp::croak("Can't validate_existing_director: $directory: Path does not exist");
    }


    unless ( -d $directory ) {
        Carp::croak("Can't validate_existing_director: $directory: path exists but is not a directory");
    }

    return 1;
}

sub validate_directory_for_read_access {
    my ($self, $directory) = @_;

    # Both underlying methods throw their own exceptions
    $self->validate_existing_directory($directory)
        or return;
    
    return $self->_can_read_from_directory($directory);
}

sub validate_directory_for_write_access {
    my ($self, $directory) = @_;

    # Both underlying methods throw their own exceptions
    $self->validate_existing_directory($directory)
        or return;
    
    return $self->_can_write_to_directory($directory);
}

sub validate_directory_for_read_write_access {
    my ($self, $directory) = @_;

    # All three underlying methods throw their own exceptions
    $self->validate_existing_directory($directory)
        or return;
    
    $self->_can_read_from_directory($directory)
        or return;

    return $self->_can_write_to_directory($directory);
}

sub _can_read_from_directory {
    my ($self, $directory) = @_;

    unless ( -r $directory ) {
        Carp::croak("Directory ($directory) is not readable");
    }

    return 1;
}

sub _can_write_to_directory {
    my ($self, $directory) = @_;

    unless ( -w $directory ) {
        Carp::croak("Directory ($directory) is not writable");
    }

    return 1;
}

sub open_directory {
    my ($self, $directory) = @_;

    my $dh = IO::Dir->new($directory);
  
    unless ($dh) {
        Carp::croak("Can't open_directory $directory: $!");
    }
    return $dh;
}


# FIXME there are several places where it excludes named pipes explicitly...
# These may not always be appropriate in the general sense, but may be
# for things under Genome::*

sub cat {
    my ($self,%params) = @_;
    my $input_files = delete $params{input_files};
    my $output_file = delete $params{output_file};
    my $mode = ($params{append_mode} ? ">>" : ">");
    
    my @addl_params;
    if ($params{append_mode}) {
        push @addl_params, (skip_if_output_is_present=>0);
    }
        
    return $self->shellcmd(
                           cmd => "cat @$input_files $mode $output_file",
                           input_files => $input_files,
                           output_files => [$output_file],
                           @addl_params
                       );
}

sub lock_resource {
    my ($self,%args) = @_;

    my $resource_lock = delete $args{resource_lock};
    my ($lock_directory,$resource_id,$parent_dir);
    if ($resource_lock) {
        $parent_dir = File::Basename::dirname($resource_lock);
        $self->create_directory($parent_dir);
        unless (-d $parent_dir) {
            Carp::croak("failed to make parent directory $parent_dir for lock $resource_lock!: $!");
        }
    }
    else {
        $lock_directory =  delete $args{lock_directory} || Carp::croak('Must supply lock_directory to lock resource');
        $self->create_directory($lock_directory);
        $resource_id = $args{'resource_id'} || Carp::croak('Must supply resource_id to lock resource');
        $resource_lock = $lock_directory . '/' . $resource_id . ".lock";
        $parent_dir = $lock_directory
    }
    my $wait_on_self = delete $args{wait_on_self} || 0;
    my $basename = File::Basename::basename($resource_lock);

    my $block_sleep = delete $args{block_sleep};
    $block_sleep = 60 unless defined $block_sleep;
    my $max_try = delete $args{max_try};
    $max_try = 7200 unless defined $max_try;

    my ($my_host, $my_pid, $my_lsf_id, $my_user) = (hostname, $$, ($ENV{'LSB_JOBID'} || 'NONE'), $ENV{'USER'});
    my $job_id = (defined $ENV{'LSB_JOBID'} ? $ENV{'LSB_JOBID'} : "NONE");
    my $lock_dir_template = sprintf("lock-%s--%s_%s_%s_%s_XXXX",$basename,$my_host,$ENV{'USER'},$$,$job_id);
    my $tempdir =  File::Temp::tempdir($lock_dir_template, DIR=>$parent_dir, CLEANUP=>1);

    unless (-d $tempdir) {
        Carp::croak("Failed to create temp lock directory ($tempdir)");
    }

    # make this readable for everyone
    chmod(0777, $tempdir) or Carp::croak("Can't chmod 0777 path ($tempdir): $!");
    
    # drop an info file into here for compatibility's sake with old stuff.
    # put a "NOKILL" here on LSF_JOB_ID so an old process doesn't try to snap off the job ID and kill me.
    my $lock_info = IO::File->new("$tempdir/info", ">");
    unless ($lock_info) {
        Carp::croak("Can't create info file $tempdir/info: $!");
    }
    $lock_info->printf("HOST %s\nPID $$\nLSF_JOB_ID_NOKILL %s\nUSER %s\n",
                       $my_host,
                       $ENV{'LSB_JOBID'},
                       $ENV{'USER'},
                     );
    $lock_info->close();

    my $ret;
    while(!($ret = symlink($tempdir,$resource_lock))) {
        # TONY: The only allowable failure is EEXIST, right?
        # If any other error comes through, we end up in bigger trouble.
         use Errno qw(EEXIST ENOENT :POSIX);
         if ($! != EEXIST) {
             $self->error_message("Can't create symlink from $tempdir to lock resource $resource_lock because: $!");
             Carp::croak($self->error_message());
         }
        my $symlink_error = $!;
        chomp $symlink_error;
        return undef unless $max_try--;
    
        my $target = readlink($resource_lock);
        # TONY: symlink could have disappeared between the top of the while loop and now
        # Is this the same as the very next case?
         if ($! == ENOENT) {
            sleep $block_sleep;
            next;
         }

         if (!$target and $! == EINVAL and -d $resource_lock) {
            $self->warning_message("Looks like $resource_lock is locked by the old scheme (not a symlink, but a directory).  Sleeping rather than doing anything scary.");
            sleep $block_sleep;
            next;
        }
        elsif (!$target || !-e $target) {
            # TONY: This means the lock symlink points to something that's been deleted
            # That's _really_ bad news and should probably get an email like below.
            $self->error_message("Lock target $target does not exist.  Dying off rather than doing anything scary.");
            Carp::croak($self->error_message);
        } 
        my $target_basename = File::Basename::basename($target);
        
        
        $target_basename =~ s/lock-.*?--//;;
        my ($host, $user, $pid, $lsf_id) = split /_/, $target_basename;

        if (not $wait_on_self and $host eq $my_host and $user eq $my_user and $pid eq $my_pid and $lsf_id eq $my_lsf_id) {
            $self->warning_message("Looks like I'm waiting on my own lock, forcing unlock...");
            $self->unlock_resource(resource_lock => $resource_lock, force => 1);
            next;
        }
        
        my $info_content=sprintf("HOST %s\nPID %s\nLSF_JOB_ID %s\nUSER %s",$host,$pid,$lsf_id,$user);
        $self->status_message("waiting on lock for resource '$resource_lock': $symlink_error. lock_info is:\n$info_content");
       
        if ($lsf_id ne "NONE") { 
            my ($job_info,$events) = Genome::Model::Event->lsf_state($lsf_id);
                 unless ($job_info) {
                     $self->warning_message("Invalid lock for resource $resource_lock\n"
                                            ." lock info was:\n". $info_content ."\n"
                                            ."Removing old resource lock $resource_lock\n");
                     unless ($Genome::Sys::IS_TESTING) {
                        my $message_content = <<END_CONTENT;
Hey Apipe,

This is a lock attempt on %s running as PID $$ LSF job %s and user %s.

I'm about to remove a lock file held by a LSF job that I think is dead.  

The resource is: 

%s

Here's info about the job that I think is gone.

%s

I'll remove the lock in an hour.  If you want to save the lock, kill me
before I unlock the process!

Your pal,
Genome::Utility::Filesystem 

END_CONTENT

                        my $msg = MIME::Lite->new(From    => sprintf('"Genome::Utility::Filesystem" <%s@genome.wustl.edu>', $ENV{'USER'}),
                                              To      => 'apipe-run@genome.wustl.edu',
                                              Subject => 'Attempt to release a lock held by a dead process',
                                              Data    => sprintf($message_content, $my_host, $ENV{'LSB_JOBID'}, $ENV{'USER'}, $resource_lock, $info_content),
                                            );
                        $msg->send();
                        sleep 60 * 60;
                 }
                     $self->unlock_resource(resource_lock => $resource_lock, force => 1);
                     #maybe warn here before stealing the lock...
               } 
           } 
        sleep $block_sleep;
       } 
    $SYMLINKS_TO_REMOVE{$resource_lock} = 1;

    # do we need to activate a cleanup handler?
    $self->cleanup_handler_check();
    return $resource_lock;
}

sub unlock_resource {
    my ($self,%args) = @_;
    my $resource_lock = delete $args{resource_lock};
    my $force = delete $args{force};

    my ($lock_directory,$resource_id);
    unless ($resource_lock) {
        $lock_directory =  delete $args{lock_directory} || Carp::croak('Must supply lock_directory to lock resource');
        $resource_id = $args{'resource_id'} || Carp::croak('Must supply resource_id to lock resource');
        $resource_lock = $lock_directory . '/' . $resource_id . ".lock";
    }

    my $target = readlink($resource_lock);
    if (!$target) {
        if ($! == ENOENT) {
            $self->error_message("Tried to unlock something that's not locked -- $resource_lock.");
            Carp::croak($self->error_message);
        } else {
            $self->error_message("Couldn't readlink $resource_lock: $!");
        }
    }
    unless (-d $target) {
        $self->error_message("Lock symlink '$resource_lock' points to something that's not a directory - $target. ");
        Carp::croak($self->error_message);
    }
    my $basename = File::Basename::basename($target);
    $basename =~ s/lock-.*?--//;;
    my ($thost, $tuser, $tpid, $tlsf_id) = split /_/, $basename;
    my $my_host = hostname;
    my $my_job_id = (defined $ENV{'LSB_JOBID'} ? $ENV{'LSB_JOBID'} : "NONE");

    unless ($force) {
        unless ($thost eq $my_host 
             && $tuser eq $ENV{'USER'} 
             && $tpid eq $$ 
             && $tlsf_id eq $my_job_id) {
        
             $self->error_message("This lock does not look like it belongs to me.  $basename does not match $my_host $ENV{'USER'} $$ $my_job_id.");
             Carp::croak($self->error_message);
        }
    }

    my $unlink_rv = unlink($resource_lock);
    if (!$unlink_rv) {
        $self->error_message("Failed to remove lock symlink '$resource_lock':  $!");
        Carp::croak($self->error_message);
    }

    my $rmdir_rv = File::Path::rmtree($target);
    if (!$rmdir_rv) {
        $self->error_message("Failed to remove lock symlink target '$target', but we successfully unlocked.");
        Carp::croak($self->error_message);
    }

    delete $SYMLINKS_TO_REMOVE{$resource_lock};
    $self->cleanup_handler_check();
    return 1;
}

# This method does _not_ throw exceptions since it seems like a non-critical method
sub check_for_path_existence {
    my ($self,$path,$attempts) = @_;

    unless (defined $attempts) {
        $attempts = 5;
    }

    while ($attempts-- > 0) {
        return 1 if -e $path;
        sleep(1);
    }
    return;
}


# FIXME - I think this is a private function to Filesystem.pm
sub cleanup_handler_check {
    my $self = shift;
    
    my $symlink_count = scalar keys %SYMLINKS_TO_REMOVE;

    if ($symlink_count > 0) {
        $SIG{'INT'} = \&INT_cleanup;
        $SIG{'TERM'} = \&INT_cleanup;
    } else {
        delete $SIG{'INT'};
        delete $SIG{'TERM'};
    }

}

END {
    exit_cleanup();
};

sub INT_cleanup {
    exit_cleanup();
    print STDERR "INT/TERM cleanup activated in Genome::Utility::Filesystem\n";
    Carp::confess;
}

sub exit_cleanup {
    for my $sym_to_remove (keys %SYMLINKS_TO_REMOVE) {
        if (-l $sym_to_remove) {
            warn("Removing remaining resource lock: '$sym_to_remove'");
            unlink($sym_to_remove) or warn "Can't unlink $sym_to_remove: $!";
        }
    }
}


sub get_classes_in_subdirectory {
    my ($subdirectory) = @_;

    unless ( $subdirectory ) {
        Carp::croak("No subdirectory given to get_classes_in_subdirectory"); 
    }

    my $genome_dir = Genome->get_base_directory_name();
    my $inc_directory = substr($genome_dir, 0, -7);
    unless ( $inc_directory ) {
        Carp::croak("Could not get inc directory for Genome.\n"); 
    }

    my $directory = $inc_directory.'/'.$subdirectory;
    return unless -d $directory;

    my @classes;
    for my $module ( glob("$directory/*pm") ) {
        $module =~ s#$inc_directory/##;
        push @classes, Genome::Utility::Text::module_to_class($module);
    }

    return @classes;
}

sub get_classes_in_subdirectory_that_isa {
    my ($subdirectory, $isa) = @_;

    unless ( $isa ) {
        Carp::confess("No isa given to get classes in directory that isa\n"); 
    }

    my @classes;
    for my $class ( get_classes_in_subdirectory($subdirectory) ) {
        next unless $class->isa($isa);
        push @classes, $class;
    }

    return @classes;
}

sub md5sum {
    my ($self, $file) = @_;

    my $digest;

    my $fh = IO::File->new($file);
    unless ($fh) {
        Carp::croak("Can't open file ($file) to md5sum: $!");
    }
    my $d = Digest::MD5->new;
    $d->addfile($fh);
    $digest = $d->hexdigest;
    $fh->close;

    return $digest;
}

sub directory_size_recursive {
    my ($self,$directory) = @_;
    my $size;
    unless (-e $directory) {
        Carp::croak("directory $directory does not exist");
    }
    find(sub { $size += -s if -f $_ }, $directory);
    return $size;
}  

sub is_file_ok {
    my ($self, $file) = @_;

    my $ok_file = $file.".ok";

    #if the file exists and is ok, return 1
    my $rv;
    eval{$rv = $self->validate_file_for_reading($file)};
    if ($rv) {
        if (-e $ok_file) {
            return 1;
        } else {
            #if the file exists, but is not ok, erase the file, return
            my $unlink_rv = unlink($file);
            $self->status_message("File $file not ok.  Deleting.");
            if ($unlink_rv ne 1) {
               Carp::croak($self->error_message("Can't unlink $file.  No ok file found."));
            }
            return;
        }
    } else {
        #if the file doesn't exist, but the ok file does, unlink the ok file.
        if (-e $ok_file) {
        	$self->status_message("File $ok_file exists but does not have an original file.  Deleting.");
            my $unlink_rv = unlink($ok_file);
            if ($unlink_rv ne 1) {
               Carp::croak($self->error_message("Can't unlink $ok_file.  No original file found."));
            }
            return;
        }
    }

    return;

}

sub mark_file_ok {
    my ($self, $file) = @_;
    
    my $ok_file = $file.".ok";

    if (-f $file ) {
        my $touch_rv = $self->shellcmd(cmd=>"touch $ok_file");
        if ($touch_rv ne 1) {
            Carp::croak($self->error_message("Can't touch ok file $ok_file."));
        } else {
            return 1;
        }
    } else {
    	$self->status_message("Not touching.  Cannot validate file for reading: ".$file);
    }
    return;
}

sub mark_files_ok {
	my ($self,%params) = @_;	
	my $input_files = delete $params{input_files};
	for my $input_file (@$input_files) {
		$self->status_message("Marking file: ".$input_file);
		$self->mark_file_ok($input_file);
	}
	return 1;
}


sub are_files_ok {

	my ($self,%params) = @_;	
	my $input_files = delete $params{input_files};
	my $all_ok = 1;
	for my $input_file (@$input_files) {
		if (!$self->is_file_ok($input_file) ) {
			$all_ok = 0;
		} 
	}
	
	if ($all_ok != 1) {
    	#delete all the files and start over
    	$self->status_message("Files are NOT OK.  Deleting files: ");
    	$self->status_message(join("\n",@$input_files));
    	for my $file (@$input_files) {
            if (-e $file){
                unlink($file) or Carp::croak("Can't unlink $file: $!");
            }
            if (-e "$file.ok"){
                unlink("$file.ok") or Carp::croak("Can't unlink ${file}.ok: $!");
            }
    	}
    	return;
    } else {
    	#shortcut this step, all the required files exist.
    	$self->status_message("Expected output files already exist.");
   	    return 1;
    }
	
	return;
}

sub remove_directory_tree {
    my ($self, $directory) = @_;
    unless (-d $directory) {
        $self->warning_message("No directory found at $directory, cannot remove");
        return;
    }

    File::Path::remove_tree($directory, { error => \my $remove_errors });
    # remove_errors will be an empty array if no errors are encountered (not undef), so
    # we've succeeded if the array has no elements
    unless (@$remove_errors) {
        my $error_summary;
        for my $error (@$remove_errors) {
            my ($file, $message) = %$error;
            if ($file eq '') {
                $error_summary .= "General error encountered, message: $message\n";
            }
            else {
                $error_summary .= "File $file, message: $message\n";
            }
        }

        if ($error_summary) {
            $self->error_message("Problems encountered removing $directory\n$error_summary");
            return;
        }
    }
    return 1;
}

1;

=pod

=head1 Name

Genome::Sys;

=head1 Synopsis

Houses some generic file and directory methods

=head1 Usage

 require Genome::Sys;

 # Call methods directly:
 Genome::Sys->create_directory($new_directory);

=head1 Methods for Files

=head2 validate_file_for_reading

 Genome::Sys->validate_file_for_reading('/tmp/users.txt')
    or ...;
 
=over

=item I<Synopsis>   Checks whether the given file is defined, exists, and is readable

=item I<Arguments>  file (string)

=item I<Returns>    true on success, false on failure

=back

=head2 open_file_for_reading

 Genome::Sys->open_file_for_reading('/tmp/users.txt')
    or die;
 
=over

=item I<Synopsis>   First validates the file for reading, then creates a IO::File for it.

=item I<Arguments>  file (string)

=item I<Returns>    IO::File object

=back

=head2 validate_file_for_writing

 Genome::Sys->validate_file_for_writing('/tmp/users.txt')
    or die;
 
=over

=item I<Synopsis>   Checks whether the given file is defined, does not exist, and that the directory it is in is writable

=item I<Arguments>  file (string)

=item I<Returns>    true on success, false on failure

=back

=head2 open_file_for_writing

 Genome::Sys->open_file_for_writing('/tmp/users.txt')
    or die;
 
=over

=item I<Synopsis>   First validates the file for writing, then creates a IO::File for it.

=item I<Arguments>  file (string)

=item I<Returns>    IO::File object

=back

=head2 copy_file

 Genome::Sys->copy_file($FROM, $TO)
    or ...;
 
=over

=item I<Synopsis>   Validates the $FROM as a file for reading, and validates the $TO as a file for writing.

=item I<Arguments>  from file (string), to file (string)

=item I<Returns>    true on success, false on failure

=back

=head1 Methods for Directories

=head2 validate_existing_directory

 Genome::Sys->validate_existing_directory('/tmp/users')
    or die;
 
=over

=item I<Synopsis>   Checks whether the given directory is defined, and is a directory (does not check permissions)

=item I<Arguments>  directory (string)

=item I<Returns>    true on success, false on failure

=back

=head2 open_directory

 Genome::Sys->open_directory('/tmp/users')
    or die;
 
=over

=item I<Synopsis>   First validates the directory, the creates a IO::Dir handle for it

=item I<Arguments>  IO::Dir (object)

=item I<Returns>    true on success, false on failure

=back

=head2 create_directory

 Genome::Sys->create_directory('/tmp/users')
    or die;
 
=over

=item I<Synopsis>   Creates the directory with the default permissions 02775

=item I<Arguments>  directory (string)

=item I<Returns>    true on success, false on failure

=back

=head1 Methods for Locking

=head2 lock_resource

Document me!

=head2 unlock_resource

Document me!

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
