# Barcode printing methods.
# Copyright (C) 2005 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package GSCApp::Print::Barcode;

=pod

=head1 NAME

GSCApp::Print::Barcode - Implements barcode printing methods.

=head1 SYNOPSIS

  use GSCApp;

=head1 DESCRIPTION

This module provides methods to print barcodes vi a daemon at the GSC.
It provides the methods to aid in the execution of the daemon, print
the barcode to the printer, and implements App::Print::barcode
printing protocol.

=head2 Data Formats

These methods can handle data from files and using Perl's standard
data structures.  There are four type of data that can be printed on
the barcode printers:

=over 4

=item barcode (up to 3 fields)

Prints a barcode up to two optional labels.  The barcode should be six
alphanumeric characters.  Each optional label will be truncated to 25
characters.

=item id (4 fields)

Prints a user id (barcode, first name, last name, userid) on a large
label from gscbarid.  The barcode should be six alphanumeric
characters.  The length of the full name (first plus last plus a
space) will be truncated to 27 characters.  The userid should be no
more than 8 characters.

=item label (1 field)

Prints a single label on a barcode sticker.  The label will be
truncated to 35 characters.

=item label6 (6 fields)

Prints a six-field (project, four quadrants, barcode), 384-well plate
information on a large label from gscbarinfo.  The barcode should be 6
alphanumeric characters.  The other fields will be truncated to 35
characters.

=back

For methods that accept files, the data should be in one of two
formats.  The default file format can store all types of data in a
single file, one per line, in the following format:

  TYPE: DATA

Where TYPE is one of the above types.  The DATA should be the fields
described above corresponding to the TYPE specified.  The fields
should be seperated by tabs (tab delimited).

The second (old) file format is still accepted for applications that
put files in the spool directories themselves (rather than use
App::Print::barcode).  In this format, the type of file, barcode or
label, is indicated by the name of the file.  Barcode files (files
with barcodes or user ids) start with the string C<barfile> while
label files (files with labels or label6s) start with the string
C<labelfile>.  Fields are tab-delimited.

For methods that accept the data directly, the type of data is passed
in via the value of the C<type> hash key.  The data is passed in via
the value of the C<data> hash key, which should be a reference to an
array.  For types other than label, the entries in this array should
themselves be reference to arrays, each with the appropriate number of
entries for the data type.  For labels, each element of the array
should be a label.

=cut

# set up module
require 5.6.0;
use strict;
use warnings;
our $VERSION = '1.7';

use base qw(App::Config);

use Carp;
use File::Basename;
use File::Temp;
use IO::Dir;
use IO::File;
use IO::Handle;
use IO::Pipe;
use Sys::Hostname;
use Time::HiRes;

use App::Path;

# this string is the barcode id image
my $barcode_id_logo = <<'EOL';
~DGDNA,00816,012,
0000000000000000000000000000ffff
fffffffffffffff00000ffffffffffff
fffffff00000ffffffea17fffffffff0
0000fffffff800fffffffff00000ffff
fffe801ffffffff00000ffffffffe803
fffffff00000fffffffffa00fffffff0
0000ffffffffffe003fffff00000ffff
fffffffc03fffff00000ffffffffc2ff
007ffff00000fffffffe00ffe00ffff0
0000fffffff8001ffc07fff00000ffff
ffc0005ffe83fff00000fffffe0002ff
ff807ff00000ffffd0000500fff00ff0
0000ffff8000007ffff00ff00000fffe
0001fffffffc01f00000fff00007ffd5
23fc01f00000ff80000000000bff80f0
0000ff80012affffffff81700000fc00
01ffffffffff80b00000fc0000000000
007f80300000e80004abffffffff8030
0000f4000ffeaaf56fff80300000e800
00000000007f80b00000f4000957ffbf
fc2d01f00000fc0001faaffffc0001f0
0000fd000000000020000ff00000ffd0
001fffff00000ff00000fff0002fffff
40007ff00000fffe000144090103fff0
0000ffff800012a0040bfff00000ffff
f4003fe0002ffff00000ffffff400000
017ffff00000ffffffd000000bfffff0
0000fffffffc00005ffffff00000ffff
fffe8000fffffff00000fffffffff800
fffffff00000ffffffc17f00bffffff0
0000fffffe0017e00bfffff00000ffff
f00007fc02fffff00000ffffd0003fff
002ffff00000fffe80015befe00bfff0
0000fffe00000000fc02fff00000fff0
0007feffff807ff00000ff80002ffbff
ffa00ff00000ff80002000001ff001f0
0000fc0001fffffffffc01f00000fc00
01fffffffffc01700000ec0000000001
447d01300000f40005dfffec117e8030
0000e8000ffffffffffd00300000f400
08aaa541007d80b00000f00000000024
be7c01f00000fc0007ffffffebfc01f0
0000fc0001f57d0800700ff00000fd00
0100004300007ff00000ff80003ffffd
0003fff00000fff0003fef10000bfff0
0000fff0002a800be07ffff00000fffe
00003f5fa3fffff00000ffff0005ffff
fffffff00000ffff8001fffffffffff0
0000fffff0003ffffffffff00000ffff
fe0007fffffffff00000ffffffc007ff
fffffff00000fffffffffffffffffff0
~DGGSC,00456,032,
00001f0
000000000000001f000000000000000e
00000007e000000000000000000007f8
000000000000007f000000000000000e
0000000ff00000200000000000000e00
00000000000000700000201000000000
0000001c000000f00000000000001c00
f0ce0f0ce70f00700f03e3183c7707cc
6707e03801e398f8f8ee000000003801
f9de3f9def1f80781f8fe738fc778e9c
ef1de03807f3bcf1f8ec000000003803
39fe739fef33803c339ce738cc7f9c1c
ff19c0700673fce398f8000000003067
71ee739ef73b001e7b18e739dc73981c
f739c0700ee3fce3b8e0000000003867
e1cee39ce77e000e7e19e779f0f7381c
e73380700fc39ce3e1e0000000003cef
03cce31ce678000f783fe7fbc0e73838
e77dc0780e0738e381c0000000003fe7
5b9cff39ce7b80de7bbfcff1eee73fb9
ce7fc07fcf7739f7ddc0000000001fe3
f39c7c39ce3f01fc3f3dc771fce73f39
ce3bc03fcfe738f3f9c0000000000200
00000000000000000001c00000000000
00038004000000000000000000000000
00000000000000000001c00000000000
00770000000000000000000000000000
00000000000000000001800000000000
003e0000000000000000000000000000
00000000000000000000000000000000
EOL

=pod

=head1 METHODS

These methods provide the ability to print barcodes at the GSC.  The
methods defined here can be used to both request the printing of
barcodes and to actually print the bar codes to a barcode printer.

=over 4

=item new

  my $bpd = GSCApp::Print::Barcode->daemon;

This method creates a new instance of the barcode printer daemon.  It
returns the barcode printer daemon object on success and C<undef> on
failure.

=cut

sub daemon
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    # create object
    my $self = { @_ };

    return bless($self, $class);
}

# check the type to make sure it is valid
sub _check_type
{
    my $self = shift;
    my ($type) = @_;

    # loop through the valid types
    foreach my $t qw(barcode label label6 id)
    {
        return 1 if $type eq $t;
    }

    $self->error_message("barcode type is invalid: $type");
    return 0;
}

# ensure barcode is valid
# return true if valid, false otherwise
sub _check_barcode
{
    my $self = shift;

    my ($barcode) = @_;

    if ($barcode)
    {
        $self->debug_message("barcode is set: $barcode", 5);
    }
    else
    {
        $self->error_message("barcode is not set");
        return;
    }

    # barcode must be five to six alphanumeric characters
    if ($barcode =~ m/^[[:alnum:]]{6}$/)
    {
        $self->debug_message("barcode valid: $barcode", 5);
    }
    elsif ($barcode eq 'empty')
    {
        $self->debug_message("empty barcode valid: $barcode", 5);
    }
    else
    {
        $self->debug_message("barcode invalid: $barcode", 5);
        return;
    }
    return 1;
}

# ensure text is valid length,
# return text trimmed to appropriate length if necessary
sub _check_text_label
{
    my $self = shift;

    my ($text, $type) = @_;

    # label can be 35 without barcode, 25 with
    # determine maximum length ot test, default to barcode
    my $max = 25;
    if ($type && $type ne 'barcode')
    {
        if ($type eq 'label')
        {
            $max = 35;
        }
        elsif ($type eq 'label6')
        {
            # arbitrary
            $max = 35;
        }
        elsif ($type eq 'id')
        {
            # name
            $max = 27;
        }
        else
        {
            $self->error_message("unknown type: $type");
            return;
        }
    }

    # make sure it is not too long
    if (length($text) <= $max)
    {
        $self->debug_message("barcode text valid: $text", 5);
    }
    else
    {
        $self->warning_message("trimming long text for $type: $text");
        $text = substr($text, 0, $max);
    }
    return $text;
}

# remove comments and whitespace from input file line
sub _clean_input
{
    my $self = shift;
    my ($line) = @_;

    # get rid of new line
    chomp($line);
    # remove comments
    $line =~ s/\#.*//;
    # remove leading white space
    $line =~ s/^\s+//;
    # remove trailing white space
    $line =~ s/\s+$//;

    return $line;
}

=pod

=item config, default_config

  GSCApp::Print::Barcdode->config(%conf);
  $bpd->config(%conf);

This class inherits from App::Config.  See L<App::Config> for details
on these methods.  Possible configuration keys:

=over 6

=item debug

Set debugging level.  Value should be an integer.

=item font

If the value of this configuration key is C<large>, text labels on
barcodes will be printed with a larger font.

=item gid

GID of group daemon should run under.

=item home

The location of the printer spool directories.

=item hostmap

Path to the file mapping locally attached printers to the servers they
are connected to.

=item hostname

Use the value of the hash key rather than the hostname obtained from
the operating system when parsing the hostmap file.

=item log

Path to log file.

=item pid

Path to run (PID) file.

=item printer_glob

Glob pattern for normal daemon (not printing to locally attached
printer) to use in home directory to obtain all spool directories.

=item sleep

Set amount of time to sleep between checking spool directories for new
files.  Value should be an integer.

=item uid

UID of user that daemon should run as.

=back

=item read_config

  %config = $bpd->read_config;

This method reads the configuration file and returns a hash of
configuration values suitable for setting using the config and
default_config method.  If an error occurs, it returns a hash with a
single key/value pair: C<(error => 1)>.  The configuration file is
line-oriented, comments begin with C<#> and continue to the end of the
line, empty lines are ignored, and data is in the following format:

  KEY=VALUE

where the above line sets the configuration option KEY equal to VALUE.

=cut

# read in configuration file
sub read_config
{
    my $self = shift;
    my (%opts) = @_;

    # combine options and config (opts override)
    %opts = ($self->config, %opts);

    # get path to config file
    if (exists($opts{path}) && $opts{path})
    {
        $self->debug_message("configuration file path set: $opts{path}", 4);
    }
    else
    {
        $self->error_message("configuration file path not set");
        return (error => 1);
    }

    # open the file
    my $fh = IO::File->new("<$opts{path}");
    if (defined($fh))
    {
        $self->debug_message("opened config file for reading: $opts{path}", 4);
    }
    else
    {
        $self->error_message("could not open file $opts{path} for reading: $!");
        return (error => 1);
    }

    # read in the file
    my %config;
    while (defined(my $line = $fh->getline))
    {
        # clean up
        $line = $self->_clean_input($line);
        next unless $line =~ m/\S/;

        $self->debug_message("processing config line: $line", 6);

        # parse the line
        my ($type, $value) = split(m/\s*=\s*/, $line);
        $type = lc($type);

        # set the config parameter
        if ($type eq 'debug' || $type eq 'sleep')
        {
            if ($value =~ m/^\d+$/)
            {
                $config{$type} = $value;
                $self->debug_message("set $type: $value", 5);
            }
            else
            {
                $self->error_message("$type value must be a number: $value");
                return (error => 1);
            }
        }
        else
        {
            $config{$type} = $value;
            $self->debug_message("set $type: $value", 5);
        }
    }
    $fh->close;

    return %config;
}

=pod

=item local_printer

  $self->local_printer;

This method determines if the daemon is running on a host with a
locally attached printer, i.e., a machine that has the printer
directly connected to its serial port.  It returns the printer name if
there is a printer attached to the host and zero (0) if it is not.
It returns C<undef> on failure.

To determine if there is a printer locally attached, it consults the
host map file specified through the hostmap configuration variable.
If this value is not set, it is assumed the daemon will not be run on
systems with locally attached printers (zero is returned).  The file
is line-oriented, comments begin with C<#> and continue to the end of
the line, empty lines are ignored, and data is in the following
format:

  PRINTER:HOST[:PORT_PATH]

where PRINTER is the name of the barcode printer attached to machine
HOST.  The option PORT_PATH should be the path to the serial port if
the printer is not connected to the first serial port on the computer.
By default the HOST is matched against the unqualified hostname
obtained from the operating system.  This behavior may be overriden by
setting the hostname configuration setting.

=cut

sub local_printer
{
    my $self = shift;

    my %opts = @_;

    # see if we were already called
    if (exists($self->{local_printer}))
    {
        $self->debug_message("using cached local_printer attribute: "
                             . $self->{local_printer}, 4);
        return $self->{local_printer};
    }

    # combine options and config
    %opts = ($self->config, %opts);

    # check map file
    if (exists($opts{hostmap}) && $opts{hostmap})
    {
        $self->debug_message("host map file set: $opts{hostmap}", 4);
    }
    else
    {
        $self->warning_message("host map file not set, no local printers");
        return $self->{local_printer} = 0;
    }

    # determine hostname
    if ($opts{hostname})
    {
        $self->debug_message("using specified hostname: $opts{hostname}", 4);
    }
    elsif ($opts{hostname} = hostname)
    {
        $self->debug_message("determined hostname: $opts{hostname}", 4);
    }
    else
    {
        $self->error_message("failed to determine hostname");
        return;
    }
    # unqualify hostname
    $opts{hostname} =~ s/\..*//;

    # open the file
    my $fh = IO::File->new("<$opts{hostmap}");
    if (defined($fh))
    {
        $self->debug_message("opened file $opts{hostmap} for reading", 4);
    }
    else
    {
        $self->error_message("failed to open file $opts{hostmap} for reading: $!");
        return;
    }

    # loop through file
    while (defined(my $line = $fh->getline))
    {
        # clean up
        $line = $self->_clean_input($line);
        next unless $line =~ m/\S/;

        my ($printer, $host, $port_path) = split(m/\s*:\s*/, $line);
        if ($printer && $host)
        {
            $self->debug_message("parsed line: $line", 5);
        }
        else
        {
            $self->error_message("failed to parse line: $line");
            return;
        }

        # see if we are that host
        if ($host eq $opts{hostname})
        {
            $self->debug_message("this host matched local host: $host", 4);
            $self->status_message("printing to local printer: $printer");

            # see if port was set
            if (defined($port_path))
            {
                # set use of non-standard port
                if ($self->local_port($port_path))
                {
                    $self->debug_message("set path to serial port: $port_path",
                                         4);
                }
                else
                {
                    # error already printed
                    return;
                }
            }

            return $self->{local_printer} = $printer;
        }
    }

    # no local printer
    return $self->{local_printer} = 0;
}

=pod

=item local_port

  $device = $bpd->local_port

Without an argument, this method determines and returns the default
path to the serial port that barcodes should be sent to on hosts with
a locally attached printer.  With a single argument, it sets the path.
It returns C<undef> on error.

=cut

sub local_port
{
    my $self = shift;
    my ($port_path) = @_;

    # see if we are setting the port
    if (@_)
    {
        # make sure path looks right (untaint)
        if ($port_path =~ m,^(/dev/[\w/]+)$,)
        {
            $port_path = $1;
            $self->debug_message("serial port path ok: $port_path", 4);
        }
        else
        {
            $self->error_message("unable to validate path to serial port: "
                                 . $port_path);
            return;
        }
        $self->{local_port} = $port_path;
    }

    # see if value has been cached
    return $self->{local_port} if $self->{local_port};

    # set default port (os dependent)
    if ($^O eq 'linux')
    {
        $self->{local_port} = '/dev/ttyS0';
    }
    elsif ($^O eq 'solaris')
    {
        $self->{local_port} = '/dev/cua/a';
    }
    else
    {
        $self->error_message("unsupported operating system: $^O");
        return;
    }

    # make sure port exists
    if (-e $self->{local_port})
    {
        $self->debug_message("serial port exists: " . $self->{local_port}, 4);
    }
    else
    {
        $self->error_message("serial port does not exist: "
                             . $self->{local_port});
        return;
    }

    return $self->{local_port};
}

=pod

=item parse_type_data

  $bpd->parse_type_data($line);
  $bpd->parse_type_data($type, @fields);
  GSCApp::Print::Barcode->parse_type_data($line);

This method validates an text string to ensure that it complies with
the default file format for the barcode print daemon.  If the string
conforms to the default file format, this method returns the type of
data and the fields split out in list.  If the string is not valid, it
returns a list with a single item, 0 (zero).  If an error occurs, and
empty list is returned.

=cut

sub parse_type_data
{
    my $self = shift;

    my ($type, $data, @fields);
    if (@_ > 1)
    {
        ($type, @fields) = @_;
        $data = join("\t", @fields);
    }
    else
    {
        my ($line) = @_;
        chomp($line);

        # make sure line has a colon
        if ($line =~ m/:/)
        {
            $self->debug_message("input has colon delimiter: $line", 4);
        }
        else
        {
            $self->warning_message("input does not have colon delimiter: $line");
            return 0;
        }

        # parse out type and validate it
        # Limit splitting to 2 chunks so $data can contain a colon
        ($type, $data) = split(m/\s*:\s*/, $line, 2);  
        if ($type)
        {
            $self->debug_message("parsed out a type: $type", 4);
        }
        else
        {
            $self->warning_message("failed to parse out a type: $line");
            return 0;
        }

        # parse out fields
        @fields = split(m/\t/, $data);
    }

    # make sure type is valid
    if ($self->_check_type($type))
    {
        $self->debug_message("type is valid: $type", 4);
    }
    else
    {
        $self->warning_message("type is not valid: $type");
        return 0;
    }

    # validate the data
    if ($type eq 'barcode')
    {
        # check barcode
        if (!$self->_check_barcode($fields[0]))
        {
            $self->error_message("barcode is invalid: $fields[0]");
            return 0;
        }

        # check text
        my $max_text = 2;
        if (@fields > $max_text + 1)
        {
            $self->warning_message("printing more than $max_text text fields "
                                   . "on a barcode is not supported: $data");
        }
        # set array to appropriate length
        $#fields = $max_text;

        # make sure all text fields are initialized
        for (my $i = 1; $i <= $max_text; ++$i)
        {
            $fields[$i] = (($fields[$i])
                           ? $self->_check_text_label($fields[$i], $type)
                           : '');
        }
    }
    elsif ($type eq 'label')
    {
        # validate label
        if ($data = $self->_check_text_label($data, $type))
        {
            $self->debug_message("label is valid", 4);
        }
        else
        {
            $self->warning_message("label is not valid: $data");
            return 0;
        }

        # make sure only one entry on array
        @fields = ($data);
    }
    elsif ($type eq 'label6')
    {
        if (@fields != 6)
        {
            $self->warning_message("must have six fields for label6: $data");
            # set length of array to 6
            $#fields = 5;
        }

        # make sure all values are at least defined
        foreach my $f (@fields)
        {
            $f ||= '';
        }

        # check barcode
        if ($fields[5] && !$self->_check_barcode($fields[5]))
        {
            $self->error_message("barcode is invalid: $fields[5]");
            return 0;
        }
    }
    elsif ($type eq 'id')
    {
        if (@fields != 4)
        {
            $self->warning_message("must specify four fields for id: $data");
            return 0;
        }

        foreach my $f (@fields)
        {
            if (!$f)
            {
                $self->warning_message("not all fields are defined for id: $data");
                return 0;
            }
        }
        
        my ($barcode, $first, $last, $userid) = @fields;

        # check barcode
        if (!$self->_check_barcode($barcode))
        {
            $self->warning_message("barcode is not valid: $barcode");
            return 0;
        }

        # combine name
        my $name = $self->_check_text_label("$first!$last", $type);

        # set array
        @fields = ($barcode, split(m/!/, $name, 2), substr($userid, 0, 8));
    }
    else
    {
        $self->error_message("thought type was valid, but is not: $type");
        return;
    }

    return $type, @fields;
}

=pod

=item daemon_loop

  App::Daemon->daemonize(loop_sub => sub { $bpd->daemon_loop });

This method is suitable for using as the daemon loop subroutine in
App::Daemon (See L<App::Daemon>).  It returns true if successful, zero
(0) for recoverable errors, and C<undef> for unrecoverable errors.

This method does more than it needs to, e.g., check the location of
the home directory, so that these things can be changed on the fly by
sending the daemon the HUP signal.

=cut

sub daemon_loop
{
    my $self = shift;

    # determine spool directories and spool method arguments
    my (@spools, %spool_args);

    # directories are relative to home
    my $home = $self->config('home');
    if ($home)
    {
        $self->debug_message("got home directory: $home", 4);
    }
    else
    {
        $self->error_message("home directory is not set");
        return;
    }
    if (-d $home)
    {
        $self->debug_message("printer home directory exists", 4);
    }
    else
    {
        $self->error_message("printer home directory does not exist: $home");
        return;
    }

    # see if we have a locally attached printer
    my $local_printer = $self->local_printer;
    if ($local_printer)
    {
        # only one spool directory
        push(@spools, "$home/$local_printer");

        # determine serial port
        $spool_args{serial_port} = $self->local_port;
        if ($spool_args{serial_port})
        {
            $self->debug_message("determined serial port: "
                                 . $spool_args{serial_port}, 5);
        }
        else
        {
            $self->error_message("unable to determine serial port");
            return;
        }
    }
    elsif (defined($local_printer)) # no local printer
    {
        # get glob expression for non-local printers
        my $globber = $self->config('printer_glob');
        if ($globber)
        {
            $self->debug_message("got printer glob pattern: $globber", 4);
        }
        else
        {
            $self->error_message("printer glob pattern not set");
            return;
        }
        push(@spools, glob("$home/$globber"));
    }
    else
    {
        $self->error_message("failed to determine local printer status");
        return;
    }

    # determine font
    my $font = $self->check_config('font');
    if ($font)
    {
        if ($font eq 'large')
        {
            $self->debug_message("printing barcodes with large font", 5);
            $spool_args{font} = $font;
        }
        # else just ignore it
    }
    else
    {
        $self->debug_message("printing normal font size", 5);
    }

    # set return value for later modification
    my $retval = 1;

    # loop through all the spool directories
    foreach my $spool (@spools)
    {
        # make sure it is a directory
        if (-d $spool)
        {
            $self->debug_message("spool is a directory", 5);
        }
        else
        {
            $self->warning_message("spool is not a directory: $spool");
            $retval = 0;
            next;
        }

        # determine printer name from spool directory for non-local printers
        if (!$local_printer)
        {
            # set printer name
            $spool_args{printer} = basename($spool);
            if ($spool_args{printer})
            {
                $self->debug_message("determined printer: $spool_args{printer}",
                                     5);
            }
            else
            {
                $self->error_message("unable to determine printer");
                $retval = 0;
                next;
            }
        }

        # open the directory
        my $dh = IO::Dir->new($spool);
        if (defined($dh))
        {
            $self->debug_message("opened spool directory", 5);
        }
        else
        {
            $self->warning_message("failed to open spool directory: $spool");
            $retval = 0;
            next;
        }

        # loop through all the files
        while (defined(my $file = $dh->read))
        {
            # ignore hidden files
            next if $file =~ m/^\./;

            # only process regular files
            my $path = "$spool/$file";
            if (-f $path)
            {
                $self->debug_message("file $path is a regular file", 6);
            }
            else
            {
                $self->debug_message("skipping non-regular file: $path", 5);
                next;
            }

            $self->debug_message("processing file: $file", 6);

            # get local copy of spool args
            my %args = %spool_args;

            # see what file format we have
            if ($file =~ m/^barfile/ || $file =~ m/^labelfile/)
            {
                # old format
                $self->debug_message("printing old format file: $path", 6);

                # determine if special type is desired
                my $type = $self->check_config('type');
                if ($type)
                {
                    if ($self->_check_type($type))
                    {
                        $self->debug_message("type is valid: $type", 5);
                        $args{type} = $type;
                    }
                    else
                    {
                        $self->error_message("type is not valid: $type");
                        return;
                    }
                }
                else
                {
                    $self->debug_message("printing default type for file name", 5);
                }
            }

            # print the file
            if ($self->spool(path => $path, %args))
            {
                $self->status_message("printed entries from file: $path");
            }
            else
            {
                $self->error_message("failed to print entries from file: $path");
                $retval = 0;
                next;
            }

            # remove the file
            if (unlink($path))
            {
                $self->debug_message("removed file after printing: $path", 6);
            }
            else
            {
                $self->error_message("could not remove file after printing: "
                                     . "$path: $!");
                $retval = 0;
                next;
            }
        }

        # close directory handle
        $dh->close;
    }

    return $retval;
}

=pod

=item hup_handler

  $SIG{HUP} = sub { $bpd->hup_handler; };

This method should be set up as the SIGHUP signal handler.

=cut

# set up HUP handler to reread configuration
sub hup_handler
{
    my $self = shift;

    $self->warning_message("received HUP signal");

    # reread configuration file
    my %new_cfg = $self->read_config;
    if (exists($new_cfg{error}) && $new_cfg{error})
    {
        $self->warning_message("failed to reread configuration file: "
                                . $self->config('path'));
        $self->warning_message("ignoring failure and continuing operation");
        return;
    }
    else
    {
        $self->debug_message("reread configuration file: "
                              . $self->config('path'), 4);
    }

    # set config
    $self->config(%new_cfg) if %new_cfg;

    return 1;
}

=pod

=item spool

  $bpd->spool
  (
      path => '/path/to/barcode/file',
      printer => 'barcode1'
  );
  $bpd->spool
  (
      path => '/path/to/label/file',
      serial_port => '/dev/ttyS0'
  );

  $bpd->spool
  (
      path => '/path/to/label/file',
      type => 'label6',
      serial_port => '/dev/cua/a'
  );

This method is called by the barcode printing daemon.  It sends the
printing instructions to the barcode printer.  It returns true upon
success, false on failure.

This method accepts files with two different formats.  The default
file format stores barcodes and labels to be printed, one per line, in
the following format:

  TYPE: DATA

Where TYPE is one of the following:

=over 6

=item barcode

Prints a barcode up to two optional labels. (up to 3 fields)

=item label

Prints a single label on a barcode sticker. (1 field)

=item label6

Prints a six-field (project, four quadrants, barcode), 384-well plate
information on a large label. (6 fields)

=item id

Prints a user id (barcode, first name, last name, userid) on a large
label. (4 fields)

=back

The DATA on the line should be the tab-delimited fields described
above for each type.

The second (old) file format is still accepted for applications
that put files in the spool directories themselves (rather than use
App::Print::barcode or lpbar/lplabel).  In this format, the type of
file, barcode or label, is indicated by the name of the file.  Barcode
files (files with barcodes or user ids) start with the string
C<barfile> while label files (files with labels or label6s) start with
the string C<labelfile>.

The possible values of the hash argument to this method are:

=over 6

=item font

If the value of this hash key is C<large>, print barcodes using a
larger font (label, label6, and id printing are not affected by this
setting).

=item path

The full path to the file containing barcodes/labels.  This entry is
required.

=item printer

To print to the IPP printer configured on the host the daemon is
running on, specify the printer name in this hash key.

=item serial_port

To print to a serial port instead of using IPP, specify the port in
this hash key.  Either the printer or serial_port entry must exist.

=item type

This key is only used when processing the old file format.  This
key should be set to one of the types listed above in the description
of the default file format.  If no type is specified, barcode is
assumed for files that begin with the string C<barfile> and label is
assumed for files that begin with the string C<labelfile>.

=back

=cut

# print barcodes and labels
sub spool
{
    my $self = shift;
    my %opts = @_;

    # combine options and config
    %opts = ($self->config, %opts);

    # make sure path was set
    if (exists($opts{path}) && $opts{path})
    {
        $self->debug_message("path is set: $opts{path}", 4);
    }
    else
    {
        $self->error_message("path is not set");
        return;
    }

    # see if file exists
    if (-f $opts{path})
    {
        $self->debug_message("file exists: $opts{path}", 4);
    }
    else
    {
        $self->error_message("file does not exist: $opts{path}");
        return;
    }

    # open barcode file
    my $bc_fh = IO::File->new("<$opts{path}");
    if (defined($bc_fh))
    {
        $self->debug_message("opened file $opts{path} for reading", 4);
    }
    else
    {
        $self->error_message("failed to open file $opts{path} for reading: $!");
        return;
    }

    # see where we should print
    my ($printer, $delay, $debug);
    if (exists($opts{printer}) && $opts{printer})
    {
        # printer should be configured on host
        $self->debug_message("printer set: $opts{printer}", 4);

        # if printing through lpr, first we'll write the data to
        # a temporary file, then use lpr to print that file
        my $tmpdir = ($^O eq 'MSWin32' || $^O eq 'cygwin') ? '/temp' : $ENV{'TMPDIR'} || '/tmp';
        $printer = File::Temp->new
        (
            DIR => $tmpdir,
            UNLINK => 1,
            TEMPLATE => App::Name->prog_name . '-XXXX'
        );
        if (defined($printer))
        {
            $self->debug_message("opened tempfile $printer for lpr", 4);
        }
        else
        {
            $self->error_message("failed to open tempfile for lpr: $!");
            return;
        }

        # set delay between barcodes
        $delay = 0;
    }
    elsif (exists($opts{serial_port}) && $opts{serial_port})
    {
        $self->debug_message("serial port set: $opts{serial_port}", 4);

        # open serial port
        $printer = IO::File->new(">>$opts{serial_port}");
        if (defined($printer))
        {
            $self->debug_message("opened serial port $opts{serial_port} for "
                                 . "appending", 4);
        }
        else
        {
            $self->error_message("failed to open serial port "
                                 . "$opts{serial_port} for appending: $!");
            return;
        }

        # set delay between barcodes
        $delay = 1.0e5; # 0.1s

        # disable buffering on printer
        $printer->autoflush(1);
    }

    # check file format and see what we are printing
    my $base = basename($opts{path});
    my $old_format = 0;
    if ($base =~ m/^barfile/ || $base =~ m/labelfile/)
    {
        # old file format
        $old_format = 1;

        # set default type if it is not set
        if (!exists($opts{type}))
        {
            $opts{type} = ($base =~ m/^barfile/) ? 'barcode' : 'label';
            $self->debug_message("set default type for old format file: "
                                 . $opts{type}, 4);
        }

        # check the type for validity
        if ($self->_check_type($opts{type}))
        {
            $self->debug_message("old format type is valid: $opts{type}", 4);
        }
        else
        {
            # error message already set
            $printer->close;
            return;
        }
    }

    # loop through the barcode file
    while (defined(my $line = $bc_fh->getline))
    {
        chomp($line);
        $self->debug_message("read barcode file line $line", 5);

        # determine what we are printing
        if ($old_format)
        {
            # make it look like the standard format
            $line = "$opts{type}:$line";
        }

        # validate the input
        my ($type, @fields) = $self->parse_type_data($line);
        if ($type)
        {
            $self->debug_message("type is valid: $type", 5);
        }
        elsif ($type == 0)
        {
            $self->error_message("invalid format: $line");
            next;
        }
        else
        {
            # error message set
            next;
        }

        # print logo if we are printing an id
        if ($type eq 'id')
        {
            $printer->print($barcode_id_logo);
        }

        # initialize the printing
        $printer->print("^XA\n");

        # send data to the printer
        if ($type eq 'barcode')
        {
            my ($barcode, @text) = @fields;

            # determine font size
            my ($f, $a);
            if (exists($opts{font}) && $opts{font} eq 'large')
            {
                $f = '2';
                $a = 'PN25,14';
            }
            else
            {
                $f = '4';
                $a = '028,17';
            }

            # send the instructions to the printer
            $printer->print("^LH15,25\n");
            $printer->print("^FO0,0^BCN,40,N,N,N,^FD$barcode^FS\n");
            $printer->print("^FO2${f}0,2^A$a^FD$text[0]^FS\n");
            $printer->print("^FO2${f}0,22^A$a^FD$text[1]^FS\n");

            $self->debug_message("printed barcode=$barcode,label=$text[0],"
                                 . "$text[1]", 5);
        }
        elsif ($type eq 'label')
        {
            $printer->print("^LH35,25\n");
            $printer->print("^FO0,0^A032,25^FD$fields[0]^FS\n");

            $self->debug_message("printed label: $fields[0]", 5);
        }
        elsif ($type eq 'label6')
        {
            $printer->print("^LH15,30\n");
            $printer->print("^FO10,0^A044,34^FD$fields[0]^FS\n");
            $printer->print("^FO50,50^A040,30^FDa1 = $fields[1]^FS\n");
            $printer->print("^FO300,50^A040,30^FDa2 = $fields[2]^FS\n");
            $printer->print("^FO50,100^A040,30^FDb1 = $fields[3]^FS\n");
            $printer->print("^FO300,100^A040,30^FDb2 = $fields[4]^FS\n");
            $printer->print("^FO475,150^A040,30^FD$fields[5]^FS\n");

            $self->debug_message("printed label6: $line", 5);
        }
        elsif ($type eq 'id')
        {
            my ($barcode, $first, $last, $userid) = @fields;
            my $name = "$first $last";
            my $start = 275 - (length($name) * 10);

            $printer->print("^FO150,44^XGGSC,1,2^FS\n");
            $printer->print("^FO25,44^GB75,220,100^FS\n");
            $printer->print("^FO25,50^FR^XGDNA,1,3^FS\n");
            $printer->print("^LH5,40^FO175,100^BCN,150,N,N,N,^FD$barcode^FS\n");
            $printer->print("^FO$start,275^A065,45^FD$name^FS\n");
            $printer->print("^FO275,320^A065,45^FD$userid^FS\n");

            $self->debug_message("printed id: $line", 5);
        }
        else
        {
            $self->error_message("thought we had a valid type but do not: "
                                 . $type);
        }

        # close out the label
        $printer->print("^XZ\n");

        # do not feed too much too fast
        Time::HiRes::usleep($delay) if $delay;
    }

    # close the file handles
    $bc_fh->close;
    $printer->close;

    # if we specified a printer, send it through lpr
    if (exists($opts{printer}) && $opts{printer})
    {
        my $rv = App::Print->print
        (
            protocol => 'lpr',
            printer => $opts{'printer'},
            path => "$printer"
        );
        if ($rv)
        {
            $self->debug_message("printed tempfile $printer via App::Print", 4);
        }
        else
        {
            $self->warning_message("failed to print tempfile $printer via "
                                   . "App::Print");
            return $rv;
        }
    }

    return 1;
}

=pod

=item default_barcode_printer

  $bp = GSCApp::Print::Barcode->default_barcode_printer;

This method does its best to determine which barcode printer the
application should print to by default.  There is no single default
printer, rather, this program tries to determine the default regular
printer for the machine and then maps that to the closest barcode
printer.  The printer mapping is contained in a file named C<bpr.map>
that is searched for in share directory of C<gsc-print>.  If no
suitable mapping is found for the default regular printer, the printer
gscbarpc is used.

This method returns the printer name upon success, false on failure.

=cut

our $default_barcode_printer;
my $default_default_barcode_printer = 'gscbarpc';

sub default_printer{ my $self = shift; $self->default_barcode_printer(@_); }

sub default_barcode_printer
{
    my $self = shift;

    # check cached value
    if ($default_barcode_printer)
    {
        $self->debug_message("returning cached value: $default_barcode_printer",
                             4);
        return $default_barcode_printer;
    }

    # try to get default regular printer
    my $lpstat = qx(lpstat -d);
    if ($?)
    {
        my $exit_val = $? >> 8;
        $self->error_message("failed to run lpstat: $exit_val: $?");
        return;
    }
    my $printer = (split(m/:\s*/, $lpstat))[1];
    if ($printer)
    {
        $self->debug_message("parsed printer from lpstat: $printer", 4);
    }
    else
    {
        $self->error_message("unable to parse printer from lpstat");
        return;
    }

    # make sure it is not just ``lp''
    if ($printer eq 'lp')
    {
        $self->debug_message("figuring out which printer is lp", 4);
        # get the printer device
        $lpstat = qx(lpstat -v $printer);
        if ($?)
        {
            my $exit_val = $? >> 8;
            $self->error_message("failed to run lpstat: $exit_val: $?");
            return;
        }

        # parse out printer name
        if ($^O eq 'solaris')
        {
            $printer = $lpstat =~ m,/dev/(\w+),;
        }
        else
        {
            # cups
            $printer = $lpstat =~ m,socket://(\w+):,;
        }
        if ($printer)
        {
            $self->debug_message("parsed printer from device: $printer", 4);
        }
        else
        {
            $self->error_message("failed to parse printer from device");
            return;
        }
    }

    # read in map file
    my ($map) = App::Path->find_files_in_path('bpr.map', 'share', 'gsc-print');
    if ($map)
    {
        $self->debug_message("found map file: $map", 4);
    }
    else
    {
        $self->debug_message("no map file found", 4);
        # return default
        return $default_barcode_printer = $default_default_barcode_printer;
    }

    # open the map file
    my $fh = IO::File->new("<$map");
    if (defined($fh))
    {
        $self->debug_message("opened map file for reading: $map", 4);
    }
    else
    {
        $self->error_message("failed to open map file for reading: $!");
        return;
    }

    while (defined(my $line = $fh->getline))
    {
        # clean up line
        $line = $self->_clean_input($line);
        next unless $line =~ m/\S/;

        my ($p, $b) = split(m/\s*:\s*/, $line);
        if ($p eq $printer)
        {
            $default_barcode_printer = $b;
            last;
        }
    }
    $fh->close;

    # make sure we have something
    $default_barcode_printer ||= $default_default_barcode_printer;
    return $default_barcode_printer;
}


=pod

=item printers

  @printers = GSCApp::Print::Barcode->printers;

Returns list of barcode printers or false on error.

=cut

our @printers;
sub printers
{
    my $class = shift;

    # use cached value if available
    return @printers if @printers;

    # get path to printer spool
    my ($spool) = App::Path->get_path('var', 'spool/bpd');
    if ($spool)
    {
        $class->debug_message("got base spool directory: $spool", 5);
    }
    else
    {
        $class->error_message("failed to get base spool directory");
        return;
    }

    # get directories (printers) in spool directory
    my $dh = IO::Dir->new($spool);
    if (defined($dh))
    {
        $class->debug_message("opened spool directory", 5);
    }
    else
    {
        $class->warning_message("failed to open spool directory: $spool: $!");
        return;
    }
    # exclude hidden files and non-directories
    @printers = grep { !m/^\./ && -d "$spool/$_" } $dh->read;
    $dh->close;

    return @printers;
}
# compatibility with old method name
use vars qw(*get_available_printer);
*get_available_printer = *printers{CODE};

# implement the barcode printing protocol
package App::Print::barcode;
use base qw(App::Print);
use App::Name;
use App::Path;
use IO::File;
use Sys::Hostname;
our $VERSION = $GSCApp::Print::Barcode::VERSION;

# parse the contents of a file of barcodes
# return list of barcode specifications
sub _parse_file
{
    my $class = shift;

    my ($path) = @_;

    # make sure path and printer were set
    if ($path)
    {
        $class->debug_message("path is set: $path", 5);
    }
    else
    {
        $class->error_message("path is not set");
        return;
    }

    # file must exist
    if (-f $path)
    {
        $class->debug_message("file $path exists and is a regular file", 4);
    }
    else
    {
        $class->error_message("file $path either does not exists or "
                              . "is not a regular file: $!");
        return;
    }

    # open file for reading
    my $fh = IO::File->new("<$path");
    if (defined($fh))
    {
        $class->debug_message("opened file $path for reading", 4);
    }
    else
    {
        $class->error_message("failed to open barcode file $path for "
                              . "for reading: $!");
        return;
    }

    # loop through file contents
    my @barcodes;
    while (defined(my $line = $fh->getline))
    {
        # clean up
        chomp($line);
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next unless $line =~ m/\S/;

        # parse the line
        my ($type, @fields) = GSCApp::Print::Barcode->parse_type_data($line);
        if ($type)
        {
            $class->debug_message("parsed line: $line", 5);
        }
        elsif ($type == 0)
        {
            $class->error_message("failed to parse line "
                                  . $fh->input_line_number . ": $line");
            next;
        }
        else
        {
            # error message set
            next;
        }

        # put valid barcode into array
        push(@barcodes, [ $type, @fields ]);
    }
    $fh->close;

    return @barcodes;
}

# create a spool file
# return true upon success, undef on failure
sub _write_spool
{
    my $class = shift;

    my ($printer, @barcodes) = @_;

    # create file in the appropriate printer spool
    my ($spool) = App::Path->get_path('var', 'spool/bpd');
    if ($spool)
    {
        $class->debug_message("got base spool directory: $spool", 5);
    }
    else
    {
        $class->error_message("failed to get base spool directory");
        return;
    }
    # append printer name
    $spool .= "/$printer";
    if (-d $spool)
    {
        $class->debug_message("printer spool directory exists: $spool", 5);
    }
    else
    {
        $class->error_message("printer spool directory does not exist: $spool");
        return;
    }

    # create unique file name
    $spool .= '/' . join('-', App::Name->prog_name, hostname,
                         App::Name->real_user_name, $$);
    while (-e $spool)
    {
        $spool .= 'x';
    }

    # open file and write contents
    # could run into problem if daemon sees file before writing done
    my $fh = IO::File->new(">$spool");
    if (defined($fh))
    {
        $class->debug_message("opened spool file for writing: $spool", 4);
    }
    else
    {
        $class->error_message("failed to open spool file for writing: $spool: $!");
        return;
    }

    # print the barcodes
    foreach my $bc_ref (@barcodes)
    {
        my ($type, @fields) = @$bc_ref;
        $fh->print("$type:", join("\t", @fields), "\n");
    }
    $fh->close;

    return 1;
}

=pod

=item App::Print::barcode::print

  App::Print->print
  (
      protocol => 'barcode',
      printer => 'barcode1',
      path => 'path/to/file'
  );

  App::Print->print
  (
      protocol => 'barcode',
      type => 'barcode',
      data =>
      [
          [ 'a1b2c3', 'first label', 'second label' ],
          [ 'd4e5f6', 'another label', 'last label' ]
      ]
  );

  App::Print->print
  (
      protocol => 'barcode',
      printer => 'barcode2',
      type => 'label'
      data => [ 'first label', 'second label', 'last label' ]
  );

  App::Print->print
  (
      protocol => 'barcode',
      printer => 'gscbarid',
      type => 'id',
      data => [ [ 'a1b2c3', 'Joey', 'Bananas', 'jbananas' ] ]
  );

  App::Print->print
  (
      protocol => 'barcode',
      printer => 'gscbarinfo',
      type => 'label6',
      data => [ [ 'project', 'a1', 'a2', 'b1', 'b2', 'd4e5f6' ] ]
  );

  App::Print->print(uri => 'barcode://barcode3/path/to/file');

This method passes the barcode(s)/label(s) to be printed to the
barcode spooling systems.  It returns true if successful, zero (0)
when the data key values contain format errors (the invalid entries
are skipped), and C<undef> on error.

The hash argument can contain the following keys:

=over 6

=item data

The data of the type specified by the type option.  The value of this
key should be a reference to an array.  The contents of the array are
determined by what type of data is being input.  See the L<"Data
Formats">.

=item path

The path to the file containing barcodes/labels to print.  The format
of the file should be the default format described in L<"Data
Formats">.

=item protocol

Value should be C<barcode> or you probably won't get here.

=item printer

The name of the barcode printer that the request should be sent to.
If the printer is not set, the printer is parsed from the C<uri> if
that key is present.  If not, the default printer is determined from
default_barcode_printer (see L<"default_barcode_printer">).

=item type

This key specifies what type of data is being passed in via the data
key.  See L<"Data Formats"> for a discussion of the data types and
formats.

=item uri

The value of this key should be a URI with the following format:

  barcode://PRINTER/absolute/path/to/file

Where C<PRINTER> is the name of the barcode printer and the remaining
characters in the URI specify the absolute path to the file to be
printed.  The file format should be the same as for path.

=back

=cut

sub print
{
    my $class = shift;
    my (%opts) = @_;

    # set default return value for later alteration
    my $retval = 1;

    # see if we need to parse the uri (protocol is set)
    if (exists($opts{uri}) && $opts{uri})
    {
        $class->debug_message("processing uri: $opts{uri}", 4);

        # get the printer name
        my ($printer) = $opts{uri} =~ m,^\s*$opts{protocol}://(\w+)/,;
        if ($printer)
        {
            $class->debug_message("uri printer is $printer", 5);
        }
        else
        {
            $class->error_message("unable to get printer from uri: $opts{uri}");
            return;
        }

        # set printer generally if it is not
        if (!$opts{printer})
        {
            $opts{printer} = $printer;
        }

        # get file name (path must be absolute)
        my ($path) = $opts{uri} =~ m,^\s*$opts{protocol}://$printer(/.+),;
        if ($path)
        {
            $class->debug_message("uri file name parsed: $path", 5);
        }
        else
        {
            $class->error_message("unable to get path from uri: $opts{uri}");
            return;
        }

        # parse file
        my @barcodes = $class->_parse_file($path);
        if (@barcodes)
        {
            $class->debug_message("parsed barcodes from uri: $opts{uri}", 4);
        }
        else
        {
            $class->error_message("failed to parse uri path: $path");
            return;
        }

        # inject barcodes into spool
        if ($class->_write_spool($printer, @barcodes))
        {
            $class->debug_message("put barcodes from uri into spool: $printer",
                                  4);
        }
        else
        {
            $class->error_message("failed to put barcodes from uri into spool: "
                                 . $printer);
            return;
        }
    }

    # store barcodes from all other possible methods
    my @barcodes;

    # check for a path source
    if (exists($opts{path}) && $opts{path})
    {
        $class->debug_message("file path set: $opts{path}", 4);

        # parse file
        my @bcs = $class->_parse_file($opts{path});
        if (@bcs)
        {
            $class->debug_message("parsed barcodes from file: $opts{path}", 4);
        }
        else
        {
            $class->error_message("failed to parse file: $opts{path}");
            return;
        }

        # push onto list
        push(@barcodes, @bcs);
    }

    # check for straight data
    if (exists($opts{type}) && $opts{type})
    {
        $class->debug_message("processing data of type: $opts{type}", 4);

        # make sure data contains what we need
        if (exists($opts{data}))
        {
            $class->debug_message("data key exists", 4);
        }
        else
        {
            $class->error_message("you specified a data type but provided no data");
            return;
        }
        if (ref($opts{data}) && ref($opts{data}) eq 'ARRAY')
        {
            $class->debug_message("data value is reference to an array", 4);
        }
        else
        {
            $class->error_message("value of data key must be array reference: "
                                 . $opts{data});
            return;
        }

        # loop through the data
        foreach my $data (@{$opts{data}})
        {
            # get data in proper format
            my @field_args;
            if ($opts{type} eq 'label')
            {
                @field_args = ($data);
            }
            else
            {
                if (ref($data) && ref($data) eq 'ARRAY')
                {
                    $class->debug_message("$opts{type} data is array ref", 5);
                }
                else
                {
                    $class->error_message("data for $opts{type} should be "
                                          . "reference to an array: $data");
                    return;
                }
                @field_args = @$data;
            }

            my ($type, @fields) = GSCApp::Print::Barcode->parse_type_data($opts{type}, @field_args);
            if ($type)
            {
                $class->debug_message("validated $opts{type} data", 5);
            }
            elsif ($type == 0)
            {
                $class->warning_message("failed to validate $opts{type} data: "
                                       . join("\t", @field_args));
                $retval = 0;
                next;
            }
            else
            {
                # error already set
                return;
            }

            # push onto list
            push(@barcodes, [ $type, @fields ]);
        }
    }

    # see if there are any barcodes to print
    if (@barcodes)
    {
        # see if printer is set
        if (exists($opts{printer}) && $opts{printer})
        {
            $class->debug_message("printer set: $opts{printer}", 4);
        }
        else
        {
            $opts{printer} = GSCApp::Print::Barcode->default_barcode_printer;
            if ($opts{printer})
            {
                $class->warning_message("using default printer: $opts{printer}");
            }
            else
            {
                $class->error_message("no printer set and unable to determine "
                                      . "default printer");
                return;
            }
        }

        # print them
        if ($class->_write_spool($opts{printer}, @barcodes))
        {
            $class->debug_message("put barcodes in spool: $opts{printer}", 4);
        }
        else
        {
            $class->error_message("failed to put barcodes in spool: "
                                  . $opts{printer});
            return;
        }
    }
    elsif ($retval)
    {
        # no parse failures, yet nothing to print
        $class->warning_message("nothing provided to print");
    }

    return $retval;
}

1;
__END__

=pod

=back

=head1 BUGS

Report bugs to <software@watson.wustl.edu>.

=head1 SEE ALSO

App(3), GSCApp(3), App::Config(3), App::Name(3), App::Path(3),
App::Print(3)

=head1 AUTHOR

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
