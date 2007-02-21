# Set up USB barcode scanner.
# Copyright (C) 2006 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

package TouchScreen::USB;

=pod

=head1 NAME

TouchScreen - manage USB barcode scanners.

=head1 SYNOPSIS

  use TouchScreen::USB;

  my $usb_scanner = TouchScreen::USB->probe();
  if ($usb_scanner) {
      $usb_scanner->open() or die;
      $::MAIN_WINDOW->fileevent($usb_scanner->fh(),
                                readable => sub { $usb_scanner->read() });
  }

=head1 DESCRIPTION

This module manages USB barcode scanners.  It queries the system to
see if a USB scanner is attached, configures it, and sets up the
application to read from scanner when barcodes are scanned.  This
module only works under Linux.

=cut

# set up package
require 5.6.0;
use warnings;
use strict;
our $VERSION = '0.2';
use base qw(App::MsgLogger);

# map event codes with keys
my @charmap = qw( - ~ 1 2 3 4 5 6 7 8 9 0 - = -
                  - q w e r t y u i o p [ ] \
                  - a s d f g h j k l ; ' ' -
                  - z x c v b n m );

=pod

=head2 METHODS

The methods deal with managing USB barcode scanners.

=over 4

=item probe

  $scanner = TouchScreen::USB->probe();

This method probes the system to see if a USB barcode scanner is
attached to the system and, if it is, returns a TouchScree::USB
object.  If no USB barcode scanner is found, it returns zero (0).  It
returns C<undef> on error.

=cut

sub probe
{
    my $class = shift;

    # only works under linux
    if ($^O ne 'linux') {
        $class->warning_message("USB barcode scanners not supported on $^O");
        return 0;
    }

    # look for scanner in proc
    my @input_devices = qx(cat /proc/bus/input/devices);
    if ($? != 0) {
        $class->error_message("failed to get input devices");
        return;
    }
    my ($name, $scanner_event);
    foreach my $line (@input_devices) {
        # parse line
        chomp($line);
        next unless $line =~ m/\S/;
        my ($tag, $desc) = split(m(:\s*), $line, 2);

        # check for device name line
        if ($tag eq 'N') {
            # new device
            if ($desc =~ m(PSC.*Scanner)) {
                $name = 'scanner';
            }
            next;
        }

        # only interested in event handler for above devices
        next unless $name;

        # look for event handler
        if ($tag eq 'H') {
            if ($desc =~ m/^Handlers=kbd (event\d+)\s*$/) {
                $scanner_event = $1;
                last; # foreach @input_devices
            }
            else {
                $class->error_message("handler line is not of correct form: $desc");
                return;
            }
        }
    }

    # see if we found one
    if ($scanner_event) {
        $class->debug_message("located USB barcode scanner: $scanner_event", 2);
    }
    else {
        $class->debug_message("no USB barcode scanner found", 2);
        return 0;
    }

    # check existance and permissions
    my $device = "/dev/input/$scanner_event";
    my $attempt = 0;
    EXIST: {
        if (-e $device) {
            $class->debug_message("USB barcode scanner device exists: $device", 2);
        }
        else {
            $class->error_message("USB barcode scanner device does not exist: $device");
            # account for delay between appearance under /proc and device
            if (++$attempt < 8) {
                sleep(1);
                redo EXIST;
            }
            return;
        }
    }
    if (-r $device) {
        $class->debug_message("USB barcode scanner device is readable: $device", 2);
    }
    else {
        $class->error_message("USB barcode scanner device is not readable: $device");
        return;
    }

    # create and return object
    return bless { event => $scanner_event, device => $device }, $class;
}


=pod

=item connected

Returns true if the scanner event device (/dev/input/event*) still exists.

=cut

sub connected {
my($self) = @_;
    -e $self->{'device'};
}

=pod

=item event

This method returns the handler event for the USB scanner.

=cut

sub event
{
    my $self = shift;

    return $self->{event};
}

=pod

=item open

    my $rv = $scanner->open();

This method opens a Linux::Input object for the USB barcode scanner.
It returns true on success, C<undef> on failure.

=cut

sub open
{
    my $self = shift;

    # check for scanner event
    my $scanner_event = $self->event();
    if ($scanner_event) {
        $self->debug_message("USB barcode scanner event: $scanner_event", 2);
    }
    else {
        $self->error_message("no event defined for this object (that is bad)");
        return;
    }

    # open the barcode event
    require Linux::Input;
    my $device = $self->{device};
    eval { $self->{input} = Linux::Input->new($device) };
    if ($@) {
        $self->error_message("failed to open USB barcode scanner device: $device: $@");
        return;
    }
    else {
        $self->debug_message("opened USB barcode scanner device: $device", 2);
    }

    # success
    return 1;
}

=pod

=item fh

  $fh = $scanner->fh();

Returns the file handle associated with the USB barcode scanner.  The
open method must be called before calling this method.

=cut

sub fh
{
    my $self = shift;
    return $self->{input}->fh();
}

=pod

=item read

  push(@barcodes, $scanner->read());

Read data from the USB barcode scanner.  It returns the list of
barcodes scanned.

=cut

my ($buffer, $shift) = ('', 0);
sub read
{
    my $self = shift;

    $self->debug_message("reading USB barcode scanner events", 2);
    my @barcodes;

    # loop through the events
    while (my @events = $self->{input}->poll(0.01)) {
        foreach my $event (@events) {
            # check for return
            if ($event->{code} == 28 && $event->{value} == 1) {
                # newline
                $self->debug_message("USB barcode scanner buffer: $buffer", 2);
                push(@barcodes, $buffer) if ($buffer);
                $buffer = '';
                next;
            }
            elsif ($event->{code} == 42) {
                # shift
                $self->debug_message("USB barcode scanner read shift: "
                                     . $event->{value}, 3);
                $shift = $event->{value};
                next;
            }
            elsif ($event->{value} == 0 || $event->{type} != 1) {
                # skip uninteresting events
                next;
            }

            # handle letter and numbers
            if ($event->{code} < @charmap) {
                my $letter = $charmap[$event->{code}];
                $self->debug_message("USB barcode scanner read letter: $letter", 3);
                next unless $letter =~ m/^[[:alnum:]]$/;

                $letter = uc($letter) if $shift;
                $buffer .= $letter;
            }
        }
    }

    return @barcodes;
}

=pod

=back

=head1 BUGS

Please report bugs to the software-support RT queue, http://rt/.

=head1 SEE ALSO

TouchAppProd(1), Linux::Input(3), App::MsgLogger(3)

=head1 AUTHOR

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
