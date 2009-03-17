package GSCApp::Print::Barcode::Intermec::EasyCoder3240;

use strict;
use warnings;
use GSCApp::Print::Barcode::Intermec;
use Net::Telnet;

our @ISA = qw(GSCApp::Print::Barcode::Intermec);

=pod

=item new

Get the instance for the printer.

PARAMS:  printer_model => $printer_model, 
         printer_name => $printer_name
RETURNS: $self

=cut

sub new {
  my $class = shift;
  my $self = { @_ };
  unless($self->{printer_name}) {
    $self->error_message('printer name must be specified and it must be the hostname for the printer.');
    return;
  }
  
  bless $self, $class;
  
  #LSF: Setup automatically.
  $self->setup();
  
  #LSF: Initialize the handle.
  #$self->handle;
  return $self;
}

=pod

=item handle

Printer handle.

PARAMS:
RETURNS: $printer_handle

=cut

sub handle_not_use {
  my $self = shift;
  unless($self->{handle}) {
    $self->{handle} = new Net::Telnet();
    $self->{handle}->open(Host => $self->{printer_name},
                          Port => $self->{port} || 9100);
  }
  return $self->{handle};
}

=pod

=item print

Print to the printer.

PARAMS: $type, @data
RETURNS: boolean

=cut

sub print {
  my $self = shift;
  my %opts = @_;
  my $type = $opts{type};
  my ($barcode, @text) = @{$opts{data}};
  return $self->handle->print("<STX><CAN><ETX>
<STX>$text[0]<CR><ETX>
<STX>$text[1]<ETX>
<STX><ESC>F2<LF>$barcode<ETX>
<STX><ETB><ETX>
");  

}

1;
#$Header: /var/lib/cvs/auto_pipeline/ips.pl,v 1.1 2006/06/09 16:09:07 sleong Exp $
