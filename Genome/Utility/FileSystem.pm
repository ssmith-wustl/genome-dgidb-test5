package Genome::Utility::FileSystem;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require File::Path;

class Genome::Utility::FileSystem {
    is => 'UR::Object',
};

sub create_directory {
    my ($self, $directory) = @_;

    unless ( defined $directory ) {
        $self->error_message("Need directory to create");
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

=head1 Methods

=head2 create_directory

 Genome::Utility::FileSystem->create_directory('/tmp/users')
    or die;
 
=over

=item I<Synopsis>   Creates the directory with the default permissions 02775

=item I<Arguments>  directory (string)

=item I<Returns>    true on success, false on failure

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
