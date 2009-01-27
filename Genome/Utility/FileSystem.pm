package Genome::Utility::FileSystem;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require IO::Dir;
require IO::File;
require File::Basename;
require File::Path;

class Genome::Utility::FileSystem {
    is => 'UR::Object',
};

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

sub shellcmd {
    # execute a shell command in a standard way instead of using system()\
    # verifies inputs and ouputs, and does detailed logging...

    # TODO: add IPC::Run's w/ timeout but w/o the io redirection...

    my ($self,%params) = @_;
    my $cmd                         = delete $params{cmd};
    my $output_files                = delete $params{output_files}
;
    my $input_files                 = delete $params{input_files};
    my $skip_if_output_is_present   = delete $params{skip_if_output_is_present} || 1;
    if (%params) {
        my @crap = %params;
        Carp::confess("Unknown params passed to shellcmd: @crap");
    }

    if ($output_files and @$output_files) {
        my @found_outputs = grep { -e $_ } @$output_files;
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
        die "ERROR RUNNING COMMAND.  Exit code $exit_code, msg $!  from: $cmd";
    }

    if ($output_files and @$output_files) {
        my @missing_outputs = grep { not -s $_ } @$output_files;
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

    my $lock_directory =  delete $args{lock_directory} || die('Must supply lock_directory to lock resource');
    my $resource_id = $args{'resource_id'} || die('Must supply resource_id to lock resource');
    my $block_sleep = delete $args{block_sleep} || 60;
    my $max_try = delete $args{max_try} || 7200;

    $self->create_directory($lock_directory);

    my $ret;
    my $resource_lock = $lock_directory . '/' . $resource_id . ".lock";
    while(!($ret = mkdir $resource_lock)) {
        return undef unless $max_try--;
        $self->status_message("waiting on lock for resource $resource_lock");
        sleep $block_sleep;
    }

    my $lock_info_pathname = $resource_lock . '/info';
    my $lock_info = IO::File->new(">$lock_info_pathname");
    $lock_info->printf("HOST %s\nPID $$\nLSF_JOB_ID %s\nUSER %s\n",
                       $ENV{'HOST'},
                       $ENV{'LSB_JOBID'},
                       $ENV{'USER'},
                     );
    $lock_info->close();

    eval "END { unlink \$lock_info_pathname; rmdir \$resource_lock;}";

    return 1;
}

sub unlock_resource {
    my ($self,%args) = @_;
    my $lock_directory = delete $args{lock_directory} || die('No lock_directory specified for unlocking.');
    my $resource_id = delete $args{resource_id} || die('No resource_id specified for unlocking.');
    my $resource_lock = $lock_directory . "/" . $resource_id . ".lock";
    unlink $resource_lock . '/info';
    rmdir $resource_lock;
    return 1;
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
