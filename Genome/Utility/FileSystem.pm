package Genome::Utility::FileSystem;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require IO::Dir;
require IO::File;
require File::Basename;
require File::Path;
require File::Copy;

class Genome::Utility::FileSystem {
    is => 'UR::Object',
};

$SIG{'INT'} = \&INT_cleanup;


my %DIR_TO_REMOVE;

#< Files >#
sub _open_file {
    my ($self, $file, $rw) = @_;

    my $fh = IO::File->new($file, $rw);

    return $fh if $fh;

    $self->error_message("Can't open file ($file): $!");
    
    return;
}

sub validate_file_for_reading {
    my ($self, $file) = @_;

    unless ( defined $file ) {
        $self->error_message("No file given");
        return;
    }

    unless ( -f $file ) {
        $self->error_message(
            sprintf(
                'File (%s) %s',
                $file,
                ( -e $file ? 'exists, but is not a file' : 'does not exist' ),
            )
        );
        return;
    }

    unless ( -r $file ) { 
        $self->error_message("Do not have READ access to file ($file)");
        return;
    }

    return 1;
}

sub open_file_for_reading {
    my ($self, $file) = @_;

    $self->validate_file_for_reading($file)
        or return;

    return $self->_open_file($file, 'r');
}

sub validate_file_for_writing {
    my ($self, $file) = @_;

    unless ( defined $file ) {
        $self->error_message("No file given");
        return;
    }

    if ( -s $file ) {
        $self->error_message("File ($file) already has data, cannot write to it");
        return;
    }

    my ($name, $dir) = File::Basename::fileparse($file);
    unless ( $dir ) {
        $self->error_message("Cannot determine directory from file ($file)");
        return;
    }
    
    unless ( -w $dir ) { 
        $self->error_message("Do not have WRITE access to directory ($dir) to create file ($name)");
        return;
    }

    return 1;
}

sub open_file_for_writing {
    my ($self, $file) = @_;

    $self->validate_file_for_writing($file)
        or return;

    unlink $file if -e $file;
    
    return $self->_open_file($file, 'w');
}

#< Dirs >#
sub validate_existing_directory {
    my ($self, $directory) = @_;

    unless ( defined $directory ) {
        $self->error_message("No directory given");
        return;
    }

    unless ( -e $directory ) {
        $self->error_message("Directory ($directory) does not exist");
        return;
    }


    unless ( -d $directory ) {
        $self->error_message("Directory ($directory) exists, but is not a directory");
        return;
    }

    return 1;
}

sub validate_directory_for_read_access {
    my ($self, $directory) = @_;

    $self->validate_existing_directory($directory)
        or return;
    
    return $self->_can_read_from_directory($directory);
}

sub validate_directory_for_write_access {
    my ($self, $directory) = @_;

    $self->validate_existing_directory($directory)
        or return;
    
    return $self->_can_write_to_directory($directory);
}

sub validate_directory_for_read_write_access {
    my ($self, $directory) = @_;

    $self->validate_existing_directory($directory)
        or return;
    
    $self->_can_read_from_directory($directory)
        or return;

    return $self->_can_write_to_directory($directory);
}

sub _can_read_from_directory {
    my ($self, $directory) = @_;

    unless ( -r $directory ) {
        $self->error_message("Cannot read from directory ($directory)");
        return;
    }

    return 1;
}

sub _can_write_to_directory {
    my ($self, $directory) = @_;

    unless ( -w $directory ) {
        $self->error_message("Cannot write to directory ($directory)");
        return;
    }

    return 1;
}

sub open_directory {
    my ($self, $directory) = @_;

    $self->validate_existing_directory($directory)
        or return;

    my $dh = IO::Dir->new($directory);

    return $dh if $dh;

    $self->error_message("Can't open directory ($directory): $!");
    
    return;
}

sub create_directory {
    my ($self, $directory) = @_;

    unless ( defined $directory ) {
        $self->error_message("No directory given to create");
        return;
    }

    return $directory if -d $directory;

    if ( -f $directory ) {
        $self->error_message("Can't create directory ($directory), already exists as a file");
        return;
    }

    if ( -l $directory ) {
        $self->error_message("Can't create directory ($directory), already exists as a symlink");
        return;
    }

    if ( -p $directory ) {
        $self->error_message("Can't create directory ($directory), already exists as a named pipe");
        return;
    }

    eval{ File::Path::mkpath($directory, 0, 02775); };

    if ( $@ ) {
        $self->error_message("Can't create directory ($directory) w/ File::Path::mkpath: $@");
        return;
    }
    
    unless (-d $directory) {
        $self->error_message("No error from 'File::Path::mkpath', but failed to create directory ($directory)");
        return;
    }

    return $directory;
}

sub create_symlink {
    my ($self, $target, $link) = @_;

    #TODO verify that it points to the given spot??
    return 1 if -l $link; 

    if ( -f $link ) {
        $self->error_message("Can't create link ($link), already exists as a file");
        return;
    }

    if ( -d $link ) {
        $self->error_message("Can't create link ($link), already exists as a directory");
        return;
    }


    unless ( symlink($target, $link) ) {
        $self->error_message("Can't create link ($link) to $target\: $!");
        return;
    }
    
    return 1;
}


sub base_temp_directory {
    my $self = shift;
    my $class = ref($self) || $self;
    my $template = shift;

    unless ($template) {
        my $time = UR::Time->now;
        $time =~ s/\s\: /_/g;
        $template = "/tmp/$class-$time--XXXX";
        $template =~ s/ /-/g;
    }
    my $dir = File::Temp::tempdir(
                                  TEMPLATE => $template,
                                  CLEANUP => 1
                              );
    $self->create_directory($dir);
    return $dir;
}

my $anonymous_temp_file_count = 0;
sub create_temp_file_path {
    my $self = shift;
    my $name = shift;
    unless ($name) {
        $name = 'anonymous' . $anonymous_temp_file_count++;
    }
    my $dir = Genome::Utility::FileSystem->base_temp_directory;
    my $path = $dir .'/'. $name;
    if (-e $path) {
        die "temp path '$path' already exists!";
    }
    return $path;
}

sub shellcmd {
    # execute a shell command in a standard way instead of using system()\
    # verifies inputs and ouputs, and does detailed logging...

    # TODO: add IPC::Run's w/ timeout but w/o the io redirection...

    my ($self,%params) = @_;
    my $cmd                         = delete $params{cmd};
    my $output_files                = delete $params{output_files}
;
    my $input_files                 = delete $params{input_files};
    my $allow_failed_exit_code      = delete $params{allow_failed_exit_code};
    my $skip_if_output_is_present   = delete $params{skip_if_output_is_present};
    $skip_if_output_is_present = 1 if not defined $skip_if_output_is_present;
    if (%params) {
        my @crap = %params;
        Carp::confess("Unknown params passed to shellcmd: @crap");
    }

    if ($output_files and @$output_files) {
        my @found_outputs = grep { -e $_ } grep { not -p $_ } @$output_files;
        if ($skip_if_output_is_present
            and @$output_files == @found_outputs
        ) {
            $self->status_message(
                "SKIP RUN (output is present):     $cmd\n\t"
                . join("\n\t",@found_outputs)
            );
            return 1;
        }
    }

    if ($input_files and @$input_files) {
        my @missing_inputs = grep { not -s $_ } @$input_files;
        if (@missing_inputs) {
            die "CANNOT RUN (missing inputs):     $cmd\n\t"
                . join("\n\t", map { -e $_ ? "(empty) $_" : $_ } @missing_inputs);
        }
    }
    $self->status_message("RUN: $cmd");
    my $exit_code = system($cmd);
    #jpeck switched exit_code to 0, was the line below 
    #my $exit_code = $self->system_inhibit_std_out_err($cmd);
    #my $exit_code = 0; 
    $exit_code /= 256;
    if ($exit_code) {
        if ($allow_failed_exit_code) {
            $DB::single = $DB::stopper;
            warn "TOLERATING Exit code $exit_code, msg $! from: $cmd";
        }
        else {
            $DB::single = $DB::stopper;
            die "ERROR RUNNING COMMAND.  Exit code $exit_code, msg $! from: $cmd";
        }
    }

    if ($output_files and @$output_files) {
        my @missing_outputs = grep { not -s $_ }  grep { not -p $_ }@$output_files;
        if (@missing_outputs) {
            for (@$output_files) { unlink $_ }
            die "MISSING OUTPUTS! @missing_outputs\n";
            #    . join("\n\t", map { -e $_ ? "(empty) $_" : $_ } @missing_outputs);
        }
    }

    return 1;
}

sub lock_resource {
    my ($self,%args) = @_;

    my $resource_lock = delete $args{resource_lock};
    my ($lock_directory,$resource_id);
    if ($resource_lock) {
        use File::Basename;
        my $parent_dir = File::Basename::dirname($resource_lock);
        $self->create_directory($parent_dir);
        unless (-d $parent_dir) {
            die "failed to make parent directory $parent_dir for lock $resource_lock!: $!";
        }
    }
    else {
        $lock_directory =  delete $args{lock_directory} || die('Must supply lock_directory to lock resource');
        $self->create_directory($lock_directory);
        $resource_id = $args{'resource_id'} || die('Must supply resource_id to lock resource');
        $resource_lock = $lock_directory . '/' . $resource_id . ".lock";
    }
    
    my $block_sleep = delete $args{block_sleep} || 60;
    my $max_try = delete $args{max_try} || 7200;

    my $ret;
    my $lock_info_pathname = $resource_lock . '/info';
    while(!($ret = mkdir $resource_lock)) {
        my $mkdir_error = $!;
        return undef unless $max_try--;
        my $info_fh = IO::File->new($lock_info_pathname);
        my $info_content;
        if ($info_fh) {
            $info_content = join('',$info_fh->getlines);
        }
        else {
            $info_content = "unable to open file: $!";
        }
        $self->status_message(
                              "waiting on lock for resource '$resource_lock':  $mkdir_error\n"
                              . "lock info is: $info_content"
                          );
        if ($info_content =~ /LSF_JOB_ID (\d+)/) {
            my $waiting_on_lsf_job_id  = $1;
            my ($job_info,$events) = Genome::Model::Command::BsubHelper->lsf_state($waiting_on_lsf_job_id);
            unless ($job_info) {
                $self->warning_message("Invalid lock for resource $resource_lock\n"
                                       ." lock info was:\n". $info_content ."\n"
                                       ."Removing old resource lock $resource_lock\n");
                $self->unlock_resource(resource_lock => $resource_lock);
            }
        }
        sleep $block_sleep;
    }

    my $lock_info = IO::File->new(">$lock_info_pathname");
    $lock_info->printf("HOST %s\nPID $$\nLSF_JOB_ID %s\nUSER %s\n",
                       $ENV{'HOST'},
                       $ENV{'LSB_JOBID'},
                       $ENV{'USER'},
                     );
    $lock_info->close();

    $DIR_TO_REMOVE{$resource_lock} = 1;
    return $resource_lock;
}

sub unlock_resource {
    my ($self,%args) = @_;
    my $resource_lock = delete $args{resource_lock};
    my ($lock_directory,$resource_id);
    unless ($resource_lock) {
        $lock_directory =  delete $args{lock_directory} || die('Must supply lock_directory to lock resource');
        $resource_id = $args{'resource_id'} || die('Must supply resource_id to lock resource');
        $resource_lock = $lock_directory . '/' . $resource_id . ".lock";
    }
    
    unless ( -e $resource_lock ) {
        return 1;
    }

    my $info_file = $resource_lock . '/info';
    unless ($self->validate_file_for_reading($info_file)) {
        $self->error_message("Resource lock info file '$info_file' not validated.");
        return;
    }
    
    my $moved_resource_lock = $resource_lock . '.stale';
    my $moved_info_file = $moved_resource_lock . '/info';
    
    if (-d $moved_resource_lock) {
            unless( rmdir $moved_resource_lock ) {
                $self->error_message("Failed to remove stale lock directory $moved_resource_lock: $!");
                return;
        }
    }
    unless  (rename $resource_lock,$moved_resource_lock) {
        $self->error_message("Failed move of $resource_lock to $moved_resource_lock");
        return;
    }
    if (!unlink($moved_info_file)) {
        $self->error_message("Failed to remove info file '$moved_info_file':  $!");
        return;
    }
    #my $moved_resource_lock = $resource_lock . '.stale';
    #my $mv_rv = File::Copy->copy($resource_lock,$moved_resource_lock);
    my $rmdir_rv = rmdir($moved_resource_lock);
    if (!$rmdir_rv) {
        $self->warning_message("Failed to remove directory '$moved_resource_lock':  $!");
        if ($self->validate_existing_directory($moved_resource_lock)) {
            opendir(DIR,$moved_resource_lock);
            my @files = map { $moved_resource_lock .'/'. $_ }  grep { $_ !~ /^\.{1,2}$/ } readdir(DIR);
            closedir(DIR);
            my $error_message;
            for (@files) {
                $error_message .= `ls -l $_`;
            }
            $self->warning_message($error_message);
        }
    }
    return 1;
}

sub check_for_path_existence {
    my ($self,$path,$attempts) = @_;

    unless (defined $attempts) {
        $attempts = 5;
    }

    my $try = 0;
    my $found = 0;
    while (!$found && $try < $attempts) {
        $found = -e $path;
        sleep(1);
        $try++;
        if ($found) {
            #$self->status_message("existence check passed: $path");
            return $found;
        }
    }
    return;
}

END {
    for my $dir_to_remove (keys %DIR_TO_REMOVE) {
        if (-e $dir_to_remove) {
            warn("Removing remaining resource lock: '$dir_to_remove'");
            File::Path::rmtree($dir_to_remove);
        }
    }
};

sub INT_cleanup {
    for my $dir_to_remove (keys %DIR_TO_REMOVE) {
        if (-e $dir_to_remove) {
            warn("Removing remaining resource lock: '$dir_to_remove'");
            File::Path::rmtree($dir_to_remove);
        }
    }
    die;
}

1;

=pod

=head1 Name

Genome::Utility::FileSystem;

=head1 Synopsis

Houses some generic file and directory methods

=head1 Usage

 require Genome::Utility::FileSystem;

 # Call methods directly:
 Genome::Utility::FileSystem->create_directory($new_directory);

=head1 Methods for Files

=head2 validate_file_for_reading

 Genome::Utility::FileSystem->validate_file_for_reading('/tmp/users.txt')
    or ...;
 
=over

=item I<Synopsis>   Checks whether the given file is defined, exists, and is readable

=item I<Arguments>  file (string)

=item I<Returns>    true on success, false on failure

=back

=head2 open_file_for_reading

 Genome::Utility::FileSystem->open_file_for_reading('/tmp/users.txt')
    or die;
 
=over

=item I<Synopsis>   First validates the file for reading, then creates a IO::File for it.

=item I<Arguments>  file (string)

=item I<Returns>    IO::File object

=back

=head2 validate_file_for_writing

 Genome::Utility::FileSystem->validate_file_for_writing('/tmp/users.txt')
    or die;
 
=over

=item I<Synopsis>   Checks whether the given file is defined, does not exist, and that the directory it is in is writable

=item I<Arguments>  file (string)

=item I<Returns>    true on success, false on failure

=back

=head2 open_file_for_writing

 Genome::Utility::FileSystem->open_file_for_writing('/tmp/users.txt')
    or die;
 
=over

=item I<Synopsis>   First validates the file for writing, then creates a IO::File for it.

=item I<Arguments>  file (string)

=item I<Returns>    IO::File object

=back

=head1 Methods for Directories

=head2 validate_existing_directory

 Genome::Utility::FileSystem->validate_existing_directory('/tmp/users')
    or die;
 
=over

=item I<Synopsis>   Checks whether the given directory is defined, and is a directory (does not check permissions)

=item I<Arguments>  directory (string)

=item I<Returns>    true on success, false on failure

=back

=head2 open_directory

 Genome::Utility::FileSystem->open_directory('/tmp/users')
    or die;
 
=over

=item I<Synopsis>   First validates the directory, the creates a IO::Dir handle for it

=item I<Arguments>  IO::Dir (object)

=item I<Returns>    true on success, false on failure

=back

=head2 create_directory

 Genome::Utility::FileSystem->create_directory('/tmp/users')
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
