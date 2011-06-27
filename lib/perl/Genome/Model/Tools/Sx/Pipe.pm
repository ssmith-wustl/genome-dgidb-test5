package Genome::Model::Tools::Sx::Pipe;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use File::Temp;
use IO::String;
use IPC::Open3;

class Genome::Model::Tools::Sx::Pipe { 
    is => 'Genome::Model::Tools::Sx',
    has => [
        commands => {
            is => 'Text',
            doc => 'String of sx (sequence transform) commands to execute.  Separate commands by a pipe w/ a space on each side ( | ). Do not include the "gmt sx", as it will be automatically added. Any sx command can be used. Ex:\n\ttrimmer bwa-style --trim-qual-length | filter by-length filter-length 70',
       },
        _fh_count => {
            is => 'Text',
            default_value => 0,
            is_optional => 1,
        },
    ],
};

#< Helps >#
sub help_brief {
    return <<HELP;
    Pipe fast qual commands together
HELP
}

sub help_detail {
    return <<HELP;
    This command pipes sx commands together, checking if each command succeeds. It will only create one set of output files. The advantage to running the commands like this is that an error in one pipe may not be conveyed through the other pipes. This could give inacurate exit codes and confusing error messages. This command hopes to capture and make sense of the errors.
HELP
}
#</>#

sub _add_result_observer { return 1; }

sub execute {
    my $self = shift;

    # Commands
    my @commands = $self->_validate_command_string( $self->commands );
    return unless @commands;

    # First process
    my @processes;
    my $first_process = $self->_create_first_process($commands[0]);
    return unless $first_process;
    push @processes, $first_process;

    # Middle processes
    for ( my $i = 1; $i < $#commands; $i++ ) {
        my $middle_process = $self->_create_middle_process($commands[$i]);
        return unless $middle_process;
        push @processes, $middle_process;
    }

    # Last process
    my $last_process = $self->_create_last_process($commands[$#commands]);
    return unless $last_process;
    push @processes, $last_process;

    # Execute each, stopping if one fails
    #print Dumper(\@processes);
    for my $process ( @processes ) {
        $self->status_message($process->{pid}.': '.join(' ', @{$process->{command_parts}}));
        #print Dumper($process);
        waitpid($process->{pid}, 0);
        my $rc = $? >> 8;
        if ( $rc == 0 ) {
            next;
        }
        $process->{error_handle}->flush;
        $process->{error_handle}->seek(0, 0);
        my $errors = '';
        while ( my $line = $process->{error_handle}->getline ) { 
            $errors .= $line;
        }
        $self->error_message('Process '.$process->{pid}." failed. Command: ".join(' ', @{$process->{command_parts}})."\nFrom STDERR:\n$errors");
        return;
    }

    return 1;
}

sub _create_first_process {
    my ($self, $command) = @_;

    my @command_parts = (qw/ gmt sx /);
    push @command_parts, split(/\s/, $command);
    push @command_parts, '--input', join(',', $self->input), '--type-in', $self->type_in;
    my $error_string;
    my $error_handle = IO::File->new(\$error_string, 'w');
    no warnings;
    my $pid = open3(
        undef, \*FH0, $error_handle, @command_parts
    );

   return { 
        pid => $pid,
        command_parts => \@command_parts,
        error_handle => $error_handle,
    };
}

sub _create_middle_process {
    my ($self, $command) = @_;

    my @command_parts = (qw/ gmt sx /);
    push @command_parts, split(/\s/, $command);
    my $error_string;
    my $error_handle = IO::File->new(\$error_string, 'w');
    my $fh_count = $self->_fh_count;
    my $out = 'FH'.($fh_count + 1);
    no strict 'refs';
    my $pid = open3(
        '<&FH'.$fh_count, \*$out, $error_handle, @command_parts,
    );
    $self->_fh_count($fh_count + 1);

    return {
        pid => $pid,
        command_parts => \@command_parts,
        error_handle => $error_handle,
    };
}

sub _create_last_process {
    my ($self, $command) = @_;

    my @command_parts = (qw/ gmt sx /);
    push @command_parts, split(/\s/, $command);
    push @command_parts, '--output', join(',', $self->output);
    push @command_parts, '--type-out', $self->type_out if $self->type_out;
    if ( defined $self->metrics_file_out ) {
        push @command_parts, '--metrics-file', $self->metrics_file_out;
    }
    my $error_string;
    my $error_handle = IO::File->new(\$error_string, 'w');
    my $fh_count = $self->_fh_count;
    my $pid = open3(
        '<&FH'.$fh_count, undef, $error_handle, @command_parts,
    );

    return {
        pid => $pid,
        command_parts => \@command_parts,
        error_handle => $error_handle,
    };
}

#< Validate Command >#
sub _validate_command_string {
    my ($self, $command_string) = @_;

    unless ( $command_string ) {
        $self->error_message('No commands given to pipe');
        return;
    }

    my @commands = split(/ \| /, $command_string);
    if ( @commands < 2 ) { 
        $self->error_message("Malformed command string: '$command_string'. Need at least 2 commands, separated by a pipe (|).");
        return;
    }

    for my $command ( @commands ) { 
        $self->validate_command($command) or return;
    }

    return @commands;
}

sub validate_command {
    my ($self, $command) = @_;

    if ( not defined $command ) { 
        $self->error_message('Cannot validate command. None given.');
        return;
    }

    if ( $command =~ /gmt/ or $command =~ /sx/ ) {
        $self->error_message("Command ($command) cannot have 'gmt' or'sx' in it.");
        return;
    }

    my @tokens = split(/\s+/, $command);
    my @subclass_parts;
    while ( my $token = shift @tokens ) {
        if ( $token =~ /^\-/ ) {
            unshift @tokens, $token;
            last;
        }
        push @subclass_parts, $token;
    }

    unless ( @subclass_parts ) {
        $self->error_message("Could not get class from command: $command");
        return;
    }

    my $class = 'Genome::Model::Tools::Sx::'.
    join(
        '::', 
        map { Genome::Utility::Text::string_to_camel_case($_) }
        map { s/\-/ /g; $_; }
        @subclass_parts
    );

    my $class_meta;
    eval{ $class_meta = $class->get_class_object; };
    if ( not $class_meta ) {
        $self->error_message("Cannot validate class ($class) for command ($command): $@");
        return;
    }

    my %params;
    if ( @tokens ) {
        my $params_string = join(' ', @tokens);
        eval{
            %params = Genome::Utility::Text::param_string_to_hash(
                $params_string
            );
        };
        unless ( %params ) {
            $self->error_message("Can't get params from params string: $params_string");
            return;
        }
    }

    my %converted_params;
    for my $key ( keys %params ) {
        if ( $key =~ /_/ ) { # underscores not allowed
            $self->error_message("Param ($key) for command ($command) params has an underscore. Use dashes (-) instead");
            return;
        }
        my $new_key = $key; 
        $new_key =~ s/\-/_/g; # sub - for _ to create processor
        my $property = $class_meta->property_meta_for_name($new_key);
        unless ( $property ) {
            $self->error_message("Cannot find property ($new_key) in class ($class)");
            return;
        }
        if ( $property->is_many and not ref($params{$key}) ) {
            $converted_params{$new_key} = [ $params{$key} ];
        }
        else {
            $converted_params{$new_key} = $params{$key};
        }
    }
    my $obj; 
    eval{
        $obj = $class->create(%converted_params);
    };
    unless ( $obj ) {
        $self->error_message("Can't validate command ($command) using class ($class)".( $@ ? ": $@" : '') );
        return;
    }
    $obj->delete;

    $self->status_message("Command OK: $command");

    return 1;
}
#<>#

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

