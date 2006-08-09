# -*-Perl-*-

##############################################
# Copyright (C) 2000 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

##############################################
# TouchScreen Interface Barcode Data Manager #
##############################################

package TouchScreen::SerialPort;

use strict;
use English;
use IO::File;
use POSIX qw(termios_h);

##########################################
# Open  serial port for reading barcodes #
##########################################
sub OpenPort {    
    my ($OS_win) = @_;
    
    my $PortObj;
    my $port;
    my $SERIAL_CFG;
    my $fh = new IO::File;
    my $TieMethod;

    if ($OS_win eq 'MSWin32') {
	eval "use Win32::SerialPort qw( :STAT 0.19 )";
	$SERIAL_CFG = '/temp/serial.cfg';
	$TieMethod = 'Win32::SerialPort';
	$port = 'COM2';
	$PortObj = Win32::SerialPort->new ($port, 'quiet');
	if (! $PortObj) {
	    $port = 'COM1';
	    $PortObj = Win32::SerialPort->new ($port, 'quiet');
	}   
	die "Can't open $port: $EXTENDED_OS_ERROR\n" unless ($PortObj);
    
	$PortObj->baudrate(9600)    || die "Failed setting $port baud rate";
	$PortObj->parity('none')    || die "fail setting $port parity";
	$PortObj->databits(8)       || die "fail setting $port databits";
	$PortObj->stopbits(1)       || die "fail setting $port stopbits";
	$PortObj->handshake('none') || die "fail setting $port handshake";
	$PortObj->write_settings    || die "fail writing $port settings";
	$PortObj->save($SERIAL_CFG)  || die "fail saving $SERIAL_CFG";
	$PortObj->close || warn "close of $port failed";
	
	my $PortObj2 = tie (*$fh, $TieMethod, $SERIAL_CFG) || die "Tie failure: $OS_ERROR";
    } else {
	
	if($OS_win eq 'solaris') {
	    $port = '/dev/ttyS1';
	}
	else {
	    $port = '/dev/ttyS0';
	}
    

	my ($sleep_count, $pid);
	my $fail = 0;
	open ($fh, "+>$port") or  $fail=1;

	if($fail) {
	    warn "port failed!\nCan NOT access $port: $!";
	    return;
	}


	
	$fh->autoflush(1);
	my ($fd_port, $term, $hld);
	
	$fd_port = $fh->fileno;
	
	$::oterm   = POSIX::Termios->new();
	$::oterm->getattr($fd_port);
	
	
	# change terminal control attributes for port.
	$term    = POSIX::Termios->new();
	$term->getattr($fd_port);
	
	$hld = $term->getoflag();
	$term->setoflag ($hld & ~(POSIX::OPOST));   # pass through unaltered.
	
	$term->setcc (VMIN, 0);
	$term->setcc (VTIME, 0);
	
	$term->setispeed (POSIX::B9600);
	$term->setospeed (POSIX::B9600);
	
	$hld = $term->getlflag();
	# turn off ICANON and ECHO (ECHO evil, bad, yuky, bla, spit, cough!)
	$hld &= ~(ECHO | ECHOK | ECHONL | HUPCL | ECHOE | ICANON | ICRNL | NOFLSH);
	$term->setlflag ($hld | IEXTEN | ISIG);
	
	$term->setattr($fd_port, POSIX::TCSAFLUSH); 
	
    }
    
    print "$port successfully opened as a filehandle.\n"  if ($::DEBUG);
    
    return ($fh);
}

1;
#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------

#
# $Header$
#
