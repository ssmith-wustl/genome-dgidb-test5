# Manage locking and unlocking our queues.
# Copyright (C) 2005 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# set package name for module
package GSCApp::QLock;

=pod

=head1 NAME

GSCApp::QLock - lock and unlock the GSC queues

=head1 SYNOPSIS

  use GSCApp;

  %rv = GSCApp::QLock->create(queue => 'csp');
  %rv = GSCApp::QLock->delete(queue => 'genqueue');
  %rv = GSCApp::QLock->status(queue => 'csp:asd');

=head1 DESCRIPTION

This module creates and deletes GSC queue locks.  It uses both
filesystem locks and PBS queue locks.  sudo is used to create or
delete a PBS queue locks.  The user must be in the C<seqmgr> to alter
such locks.

See /gsc/scripts/share/qlock/queues for the configuration file.

=cut

# set up package
require 5.6.0;
use warnings;
use strict;
our $VERSION = '0.2';
use base qw(App::MsgLogger);
use File::Basename;
use IO::File;
use App::Lock;
use App::Path;

=pod

=head2 METHODS

These methods create, test, and delete locks.

=over 4

=cut

our %queues;
sub _read_config
{
    my $class = shift;

    # read config if it has not been read in yet
    return 1 if %queues;

    # parse the config file
    my $config_file = (App::Path->find_files_in_path('queues', 'share', 'qlock'))[0];
    if ($config_file)
    {
        $class->debug_message("found config file: $config_file", 4);
    }
    else
    {
        $class->error_message("could not find config file");
        return;
    }

    # open the file
    my $config_fh = IO::File->new("<$config_file");
    if (defined($config_fh))
    {
        $class->debug_message("opened config file for reading: $config_file", 4);
    }
    else
    {
        $class->error_message("failed to open config file: $config_file: $!");
        return;
    }
    my $queue;
    while (defined(my $line = $config_fh->getline))
    {
        # clean up
        chomp($line);
        $line =~ s/\#.*//;
        next unless $line =~ m/\S/;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        # parse the line
        my ($tag, $value) = split(m/\s*=\s*/, $line, 2);
        if (!$tag)
        {
            $class->warning_message("unable to parse config line: $line");
            next;
        }

        # make sure we start with a name
        if ($tag eq 'queue')
        {
            $queue = $value;
            next;
        }
        elsif (!$queue)
        {
            $class->error_message("invalid configuration, does not start "
                                 . "with queue field: $line");
            return;
        }

        # set the config value
        push(@{$queues{$queue}{$tag}}, $value);
    }

    return 1;
}

# create a lock file
# return 1 if successful, 0 if lock exists, undef on error
sub _file_create
{
    my $class = shift;
    my %opts = @_;

    my $lock = App::Lock->create
    (
        mechanism => 'file_simple',
        lock_file => $opts{file},
        comment => $opts{comment} || "lock created by $class",
        block => 0
    );
    if ($lock)
    {
        $class->debug_message("created lock file: $opts{file}", 5);
    }
    elsif (defined($lock))
    {
        $class->warning_message("lock file already exists: $opts{file}");
        return 0;
    }
    else
    {
        $class->error_message("failed to create lock file: $opts{file}");
        return;
    }

    # make the lock persistent
    $lock->persistent(1);

    return 1;
}

# remove a lock file
# return 1 if successful, 0 if no lock to delete, undef on error
sub _file_delete
{
    my $class = shift;
    my %opts = @_;

    # see if file exists
    if (-f $opts{file})
    {
        $class->debug_message("lock file exists: $opts{file}", 5);
    }
    else
    {
        $class->warning_message("lock file does not exist: $opts{file}: $!");
        return 0;
    }

    # remove the file
    if (unlink($opts{file}))
    {
        $class->debug_message("removed lock file: $opts{file}", 5);
    }
    else
    {
        $class->error_message("failed to remove lock file: $opts{file}: $!");
        return;
    }

    return 1;
}

# return status of a lock file
# return 1 if locked, 0 if not locked, undef on error
sub _file_stat
{
    my $class = shift;
    my %opts = @_;

    # see if file exists
    if (-f $opts{file})
    {
        $class->debug_message("lock file exists: $opts{file}", 5);
        my $fh = IO::File->new("<$opts{file}");
        if (defined($fh))
        {
            $class->debug_message("opened lock file for reading: $opts{file}", 5);
        }
        else
        {
            $class->warning_message("lock file exists but could not be opened "
                                    . "for reading: $opts{file}: $!");
            return "lock file exists";
        }
        my $contents = '';
        while (defined(my $line = $fh->getline))
        {
            $contents .= $line;
        }
        $fh->close;
        return $contents;
    }
    elsif ($! =~ m/No such file or directory/)
    {
        $class->debug_message("lock file does not exist: $opts{file}", 5);
        return 0;
    }
    # else
    $class->error_message("error getting status of file: $!");
    return;
}

# alter state of pbs queue
# return 1 if successful, undef on error
sub _pbs_alter
{
    my $class = shift;
    my %opts = @_;

    # create qmgr command
    my @pbs_cmd = qw(sudo -u seqmgr /gsc/bin/qmgr -c);
    push(@pbs_cmd, "set queue $opts{queue} started = $opts{pbs_arg}", 'qblade');
    $class->status_message("running command to alter pbs $opts{queue} queue...");
    $class->status_message("you may be prompted for your password");
    my $rv = system(@pbs_cmd);
    if ($rv == 0)
    {
        $class->debug_message("ran qmgr command sucessfully", 5);
    }
    else
    {
        $class->error_message("pbs qmgr command failed: $rv");
        return;
    }

    return 1;
}

# check status of queue
# return 1 if locked, 0 if not locked, undef on error
sub _pbs_stat
{
    my $class = shift;
    my %opts = @_;

    my @qstat = qx(qstat -Q $opts{queue}\@qblade);
    if ($? == 0)
    {
        $class->debug_message("", 5);
    }
    else
    {
        $class->error_message("pbs qstat command failed: $?");
        return;
    }

    # get started status
    my $started = (split(' ', pop(@qstat)))[4];
    if ($started eq 'no')
    {
        $class->debug_message("pbs queue is locked: $opts{queue}", 5);
        return 1;
    }
    elsif ($started eq 'yes')
    {
        $class->debug_message("pbs queue is not locked: $opts{queue}", 5);
        return 0;
    }
    # else
    $class->error_message("unexpected pbs queue status: $opts{queue}: $started");
    return;
}

# generic queue altering method
sub _queue
{
    my $class = shift;
    my %opts = @_;

    # make sure the config has been processed
    if ($class->_read_config)
    {
        $class->debug_message("config has been processed", 4);
    }
    else
    {
        $class->error_message("failed to read configuration");
        return;
    }

    # make sure the directory was specified
    if (exists($opts{queue}))
    {
        $class->debug_message("hash key queue exists", 4);
    }
    else
    {
        $class->error_message("no queue specified");
        return;
    }
    if ($opts{queue})
    {
        $class->debug_message("hash key queue defined: $opts{queue}", 4);
    }
    else
    {
        $class->error_message("queue option given but value undefined");
        return;
    }

    # make sure queue exists in config
    if (exists($queues{$opts{queue}}))
    {
        $class->debug_message("config for queue exists: $opts{queue}");
    }
    else
    {
        $class->warning_message("config for queue does not exist: $opts{queue}");
        return;
    }

    # if we got this far, we are going to try to act, so save return values
    my %rv;
    # see if we need to make a lock file
    if (exists($queues{$opts{queue}}{file}) && exists($opts{file_op}))
    {
        foreach my $lfile (@{$queues{$opts{queue}}{file}})
        {
            # call the file_op method (pass $class as first argument)
            $rv{file}{$lfile} = $opts{file_op}->($class, %opts, file => $lfile);
            if ($rv{file}{$lfile})
            {
                $class->debug_message("lock file successful: $lfile", 5);
            }
            elsif (defined($rv{file}{$lfile}))
            {
                $class->debug_message("zero return status for file: $lfile", 5);
            }
            else
            {
                $class->error_message("operation failed on lock file: $lfile");
            }
        }
    }

    # see if we need to alter a pbs queue
    if (exists($queues{$opts{queue}}{pbs}) && exists($opts{pbs_op}))
    {
        foreach my $q (@{$queues{$opts{queue}}{pbs}})
        {
            $rv{pbs}{$q} = $opts{pbs_op}->($class, %opts, queue => $q);
            if ($rv{pbs}{$q})
            {
                $class->debug_message("pbs queue operation successful: $q", 5);
            }
            elsif (defined($rv{pbs}{$q}))
            {
                $class->debug_message("zero return status for pbs queue: $q", 5);
            }
            else
            {
                $class->error_message("pbs queue operation failed: $q");
            }
        }
    }

    return %rv;
}

=pod

=item create

    GSCApp::QLock->create(queue => 'csp:at', comment => 'whodunit');

This method locks the queue given by the queue hash key argument.  If
a comment is provided and the locking creates a lock file, the comment
is used as the contents of the lock file.

The return value of this method is a hash.  The hash keys are the type
of locks created.  The values of the hash are hashrefs themselves
containing the lock names as keys and whether the lock creation was
successful (true) or unsuccessful (C<undef>) as values.  If no locks
were created successfully, false is returned.

=cut

sub create
{
    my $class = shift;

    return $class->_queue
    (
        @_,
        file_op => \&_file_create,
        pbs_op => \&_pbs_alter,
        pbs_arg => 'False'
    );
}

=pod

=item create

    GSCApp::QLock->delete(queue => 'csp:at');

This method unlocks the queue given by the queue hash key argument.

The return value of this method is a hash.  The hash keys are the type
of locks deleted.  The values of the hash are hashrefs themselves
containing the lock names as keys and whether the lock deletion was
successful (true) or unsuccessful (C<undef>) as values.  If no locks
were deleted successfully, false is returned.

=cut

sub delete
{
    my $class = shift;

    return $class->_queue
    (
        @_,
        file_op => \&_file_delete,
        pbs_op => \&_pbs_alter,
        pbs_arg => 'True'
    );
}

=pod

=item status

    GSCApp::QLock->status(queue => 'csp:at');

Return lock status of queue.  The return value of this method is a
hash.  The hash keys are the type of locks.  The values of the hash
are hashrefs themselves containing the lock names as keys and whether
the lock exists (true) or not (zero (0)) as values.  If there was an
error getting the status of a lock, its hash value will be C<undef>.
If no statues were created queried successfully, false is returned.

=cut

sub status
{
    my $class = shift;

    return $class->_queue
    (
        @_,
        file_op => \&_file_stat,
        pbs_op => \&_pbs_stat
    );
}

1;
__END__

=pod

=back

=head1 BUGS

Please report bugs to the software-support queue in RT.

=head1 SEE ALSO

qlock(1), App(3), GSCApp(3), App::Lock(3), sudo(8)

=head1 AUTHOR

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
