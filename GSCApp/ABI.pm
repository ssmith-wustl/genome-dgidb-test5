# Central module for interacting with GSC ABI machines
# Copyright (C) 2006 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# set package name for module
package GSCApp::ABI;

use warnings;
use strict;

use base qw(App::MsgLogger);

=pod

=head1 NAME

GSCApp::ABI - Central module for interacting with GSC ABI machines

=head1 SYNOPSIS

  use GSCApp;

  my $result=GSCApp::ABI->ls(host_number => $host_number,
                             directory   => $abi_run_directory);

=head1 DESCRIPTION

This module is meant to provide a simple interface for executing
SMB commands to talk to the GSC ABI machines.  It is GSC specific,
although some of this functionality could probably be split apart
from the GSC-specific ones.

=head2 METHODS

The methods allow for you to run your own SMB commands, as well as
providing certain convienence functions for often-used commands.

=over 4

=cut

my $smb_client;
sub smb_client {
    my $self=shift;

    unless(defined($smb_client)) {
        $smb_client=$self->_find_smb_client || '';
    }

    return $smb_client;
}

sub _find_smb_client {
    my $self=shift;
    
    my $find_smb_command=qq(which smbclient);
    my $smb_client=qx($find_smb_command);
    my $error=$?>>8;
    chomp $smb_client;
    
    if($error || ! $smb_client) {
        # Find command didn't work for some reason
        $self->warning_message("Could not find smbclient");
        return;
    }

    return $smb_client;
}

sub build_smb_command {
    my $self=shift;
    my %params=@_;
    
    # Find out where we're headed
    my $abi_host=$params{host};
    unless($abi_host) {
        my $host_number=$params{host_number};
        $abi_host='nt'.$host_number;
    }
    
    unless($abi_host) {
        $self->warning_message("Must specify an ABI host to connect to");
        return;
    }
    
    my $share=$params{share}||'e$'; # Default share is the E: drive

    # Find the SMB Client executable
    my $smb_client=$self->_find_smb_client;
    unless($smb_client) {
        $self->warning_message("SMB Client is not available");
        return;
    }

    # Default Options
    my %options=('-p' => 139,
                 '-U' => 'transferuser%tranxf3rus3r1',
                );

    # # nt100 isn't in the same domain as the regular ABIs and just has a local use defined
    unless ($abi_host =~ m/nt100/i) {
        $options{'-W'} = 'gscseq';
    }
    
    # Add options passed in
    # Add directory
    if(exists $params{directory}) {
        $options{'-D'}='"'.$params{directory}.'"';
    }

    # Add command
    if(exists $params{command}) {
        if(ref($params{command}) eq 'ARRAY') {
            $options{'-c'}=
                '"'.
                join('; ', @{$params{command}}).
                '"';
        } else {
            $options{'-c'}='"'.$params{command}.'"';
        }
    }

    # Build the SMB command
    my $smb_command=qq($smb_client '//$abi_host/$share');
    foreach my $opt (keys %options) {
        $smb_command.=" $opt $options{$opt}";
    }

    return($smb_command);
}

sub run_abi_command {
    ###MAKE IT RETURN A RESULT OBJECT

    my $self=shift;
    my %params=@_;

    unless(exists $params{command}) {
        $self->error_message("You must specify a command if using _interact_with_abi.".
                             "  If you want to run an interactive session, use _build_smb_command".
                             " to get the command and run it yourself");
        return;
    }
    
    my $smb_command=$self->build_smb_command(%params);

    my $result=new GSCApp::ABI::result;

    unless($smb_command) {
        $self->error_message("Could not interact with ABI:  error building smb command:  ".$self->error_message);
        $result->set_error("Error building smb comand:  ".$self->error_message);
        return $result;
    }

    $result->command($smb_command);

    # Add redirection
    $smb_command.=' 2>&1';
    $self->status_message("Running smb command:  $smb_command");
    my @output=`$smb_command`;
    $result->command_output(\@output);
    
    my $exit_value=$?>>8;
    $result->exit_value($exit_value);
    if($exit_value) {
        $self->warning_message("SMB command returned a non-zero value:  $exit_value");
    }

    return $result;
}

=pod

=item ls

  my $result=GSCApp::ABI->ls(host_number => $host_number,
                             directory   => $abi_run_directory);

Of course, you will want more POD for this function.  Who wouldn't?
But right now, it's still forthcoming.

=cut

sub ls {
    my $self=shift;
    my %params=@_;

    if(exists $params{command}) {
        if($params{command} &&
           $params{command} eq 'ls') {
            $self->warning_message("_smbclient_ls already has ls as command, you don't need to specify it");
        } else {
            $self->error_message("Command passed into _smbclient_ls; this is not allowed");
            return;
        }
    }

    $params{command}='ls';
    my $result=$self->run_abi_command(%params);

    if($result->error_message) {
        $self->error_message("Error in SMB ls:  ".$result->error_reason);
        return $result;
    }

    my $output=$result->command_output;
    unless($output && @$output) {
        $result->set_error("Failed to get file listing:  ".$self->error_message);
        $self->error_message("Failed to get file listing:  ".$self->error_message);
        return $result;
    } 

    if(grep {/NOT_FOUND/} @$output) {
        $self->warning_message("Directory given was not found on the ABI");
        $result->set_error("Directory was not found on the ABI");
        return $result;
    }

    my @processed_output=@$output;
    # Remove header and trailer
    for (1..2) { shift @processed_output }
    for (1..2) { pop @processed_output }
    
    # Remove the . and .. directories
    @processed_output=grep { not /^\s*\.+\s+D/ } @processed_output;
    chomp @processed_output;
    $result->processed_result(\@processed_output);

    return $result;
}

sub parse_abi_run_path {
    my $class=shift;
    # Parses a given ABI run path into it's various components:
    # host, share, and directory

    my $abi_run_path=shift;
    my ($abi_host, $abi_share, $abi_path)=($abi_run_path =~ m|^\\\\(.*?)\\(.*?)\\(.*)$|);

    return unless($abi_host && $abi_share && $abi_path);
    return($abi_host, $abi_share, $abi_path);
}

1;

package GSCApp::ABI::result;

use warnings;
use strict;

sub other_properties {
    qw/
        error
        error_reason
        command
        exit_value
        command_output
        processed_result
        /;
}

foreach my $property (other_properties()) {
    # Code grabbed from App::Object::Class->mk_rw_accessor
    my $accessor = sub {
        if (@_ > 1) {
            my $old = $_[0]->{ $property };
            my $new = $_[1];
            if ($old ne $new) {
                $_[0]->{ $property } = $new;
            }
            return $new;
        }
        return $_[0]->{ $property };
    };
    
    no strict 'refs';
    
    *{__PACKAGE__."::$property"}  = $accessor;
}

sub new {
    my $class=shift;
    my %params=@_;

    # Do parameter checking

    my $self={};
    # Set parameters
    # (Mainly to avoid warnings later)
    foreach my $property (other_properties()) {
        $self->{$property}='';
    }

    bless $self, $class;
    return $self;
}

sub set_error {
    my $self=shift;
    $self->error_message(1);

    my $error_reason=shift || 'unknown';
    $self->error_reason($error_reason);

    return $self;
}

sub result {
    my $self=shift;

    # The purpose of this function is to allow certain functions to process the output
    # of the command and return what is appropriate for that function, while not
    # forcing the caller to know specifically where to look for the "return" of the
    # function

    return $self->processed_result if($self->processed_result);
    return $self->command_output;
}

1;

=pod

=back

=head1 BUGS

Please report bugs to the software-support queue in RT.

=head1 SEE ALSO

App(3), GSCApp(3)

=head1 AUTHOR

Ken Swanson <kswanson@watson.wustl.edu>

=cut

#$Header$
