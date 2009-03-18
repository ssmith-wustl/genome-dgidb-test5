package GSCApp::Print::Barcode::Zebra;

use strict;
use warnings;
use Carp;
use GSCApp::Print::Barcode::Interface;

our @ISA = qw(GSCApp::Print::Barcode::Interface);
# this string is the barcode id image
our $BARCODE_ID_LOGO = <<'EOL';
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

=head1 description

Interface for the Zebra barcode printer.

=cut

=pod

=item instance

Get the instance for the printer.

PARAMS:  printer_model => $printer_model, 
         printer_name => $printer_name,
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
  my $self = \%params;
  bless $self, $class;
  return $self;
}

=pod

=item setup

Setup the printer for printing barcodes.

Overriden here to return set the samething every call.

PARAMS:
RETURNS: boolean

=cut

sub setup {
  my $self = shift;
  $self->handle->print("^XA\n");
  
 return 1;
}

=pod

=item print_barcode

Print to the printer.

PARAMS: data => $data, type => $type
RETURNS: boolean

=cut

sub print_barcode {
  my $self = shift;
  my %opts = @_;
  my $type = $opts{type};
  my ($barcode, @text) = @{$opts{data}};
  # determine font size
  my ($f, $a) = exists($opts{font}) && $opts{font} eq 'large' ? 
                      ('2', 'PN25,14') : 
                      ('4', '028,17');

  $self->setup(@_);
  # send the instructions to the printer
  $self->handle->print("^LH15,25\n");
  $self->handle->print("^FO0,0^BCN,40,N,N,N,^FD$barcode^FS\n");
  $self->handle->print("^FO2${f}0,2^A$a^FD$text[0]^FS\n");
  $self->handle->print("^FO2${f}0,22^A$a^FD$text[1]^FS\n");
  $self->debug_message("printed barcode=$barcode,label=$text[0],"
                       . "$text[1]", 5);
  # close out the label
  $self->handle->print("^XZ\n");
  return 1;  
}

=pod

=item print_id

Print to the printer.

PARAMS: data => $data, type => $type
RETURNS: boolean

=cut

sub print_id {
  my $self = shift;
  my %opts = @_;
  my $type = $opts{type};
  # determine font size
  $self->handle->print($BARCODE_ID_LOGO);
  $self->setup(@_);
  my ($barcode, $first, $last, $userid) = @{$opts{data}};
  my $name = "$first $last";
  my $start = 275 - (length($name) * 10);

  $self->handle->print("^FO150,44^XGGSC,1,2^FS\n");
  $self->handle->print("^FO25,44^GB75,220,100^FS\n");
  $self->handle->print("^FO25,50^FR^XGDNA,1,3^FS\n");
  $self->handle->print("^LH5,40^FO175,100^BCN,150,N,N,N,^FD$barcode^FS\n");
  $self->handle->print("^FO$start,275^A065,45^FD$name^FS\n");
  $self->handle->print("^FO275,320^A065,45^FD$userid^FS\n");
  $self->debug_message("printed id: " . (join "\t", @{$opts{data}}), 5);
  # close out the label
  $self->handle->print("^XZ\n");
  return 1;
}

=pod

=item print_label

Print to the printer.

PARAMS: data => $data, type => $type
RETURNS: boolean

=cut

sub print_label {
  my $self = shift;
  my %opts = @_;
  my $type = $opts{type};
  my @fields = @{$opts{data}};
  $self->setup(@_);
  $self->handle->print("^LH35,25\n");
  $self->handle->print("^FO0,0^A032,25^FD$fields[0]^FS\n");
  $self->debug_message("printed label: $fields[0]", 5);
  # close out the label
  $self->handle->print("^XZ\n");
}

=pod

=item print_label

Print to the printer.

PARAMS: data => $data, type => $type
RETURNS: boolean

=cut

sub print_label6 {
  my $self = shift;
  my %opts = @_;
  my $type = $opts{type};
  my @fields = @{$opts{data}};
  $self->setup(@_);
  $self->handle->print("^LH15,30\n");
  $self->handle->print("^FO10,0^A044,34^FD$fields[0]^FS\n");
  $self->handle->print("^FO50,50^A040,30^FDa1 = $fields[1]^FS\n");
  $self->handle->print("^FO300,50^A040,30^FDa2 = $fields[2]^FS\n");
  $self->handle->print("^FO50,100^A040,30^FDb1 = $fields[3]^FS\n");
  $self->handle->print("^FO300,100^A040,30^FDb2 = $fields[4]^FS\n");
  $self->handle->print("^FO475,150^A040,30^FD$fields[5]^FS\n");
  $self->debug_message("printed label6: " . (join "\t", @fields), 5);
  # close out the label
  $self->handle->print("^XZ\n");
}

=pod

=item close

Close the printer handle.

PARAMS:
RETURNS: boolean

=cut

sub close {
  my $self = shift;
  return $self->handle->close()
}

1;
#$Header: /var/lib/cvs/auto_pipeline/ips.pl,v 1.1 2006/06/09 16:09:07 sleong Exp $
