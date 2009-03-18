package GSCApp::Print::Barcode::Intermec;

use strict;
use warnings;
use Carp;
use GSCApp::Print::Barcode::Interface;

our @ISA = qw(GSCApp::Print::Barcode::Interface);

=pod

=head1 description

Interface for the Intermec barcode printer.

=cut

=pod

=item new

Get the instance for the printer.

PARAMS:  printer_model => $printer_model, 
         printer_name => $printer_name
RETURNS: $self

=cut

sub new {
  my $class = shift;
  my %params = @_;
  if($params{printer_model}) {
    my $printer_model = delete $params{printer_model};
    my $subclass_name = App::Vocabulary->make_class_name_portion($printer_model);
    my $subclass = $class . '::' . $subclass_name;
    if($subclass->require) {
      return $subclass->new(%params);
    }
  }
  $class->error_message('not printer model found.'); 
  return;
}

=pod

=item setup_barcode

Setup the printer for printing barcodes.

PARAMS:  type => $type
RETURNS: boolean

=cut

sub setup_barcode {
  my $self = shift;
  if($self->{current_setup} && $self->{current_setup} eq 'barcode') {
    return 1;
  }
  $self->{current_setup} = 'barcode';
  $self->handle->print('
<STX><ESC>C<ETX>
<STX><ESC>P<ETX>
<STX>E3;F3<ETX>
<STX>H0;o0,190;f1;c0;d0,30;h1;w1;<ETX>
<STX>H1;o20,190;f1;c0;d1,30;h1;w1;<ETX>
<STX>B2;o0,420;f1;c6,0;h32;w2;d2,10;i0;<ETX>
<STX>R;<ETX>
<STX><ESC>E3<ETX>
');
  
 return 1;
}

=pod

=item setup_label

Setup the printer for printing label.

PARAMS:
RETURNS: boolean

=cut

sub setup_label {
  my $self = shift;
  if($self->{current_setup} && $self->{current_setup} eq 'label') {
    return 1;
  }
  $self->{current_setup} = 'label';
  $self->handle->print('
<STX><ESC>C<ETX>
<STX><ESC>P<ETX>
<STX>E1;F1<ETX>
<STX>H0;o0,420;f1;c0;d0,30;h2;w2;<ETX>
<STX>R;<ETX>
<STX><ESC>E1<ETX>
');
  
 return 1;
}

1;
#$Header: /var/lib/cvs/auto_pipeline/ips.pl,v 1.1 2006/06/09 16:09:07 sleong Exp $
