package GSCApp::Print::Barcode::Interface;

use strict;
use warnings;
use Carp;
use UNIVERSAL::require;

our @ISA = qw(GSCApp::Print::Barcode);

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

PARAMS:
RETURNS: boolean

=cut

sub setup {
  my $self = shift;
  my %opts = @_;
  my $type = $opts{type};
  if(my $ref = $self->can('setup_' . $type)) {
    return $self->$ref(@_);
  }
  $self->error_message("thought we had a valid type but do not: "
                                 . $type);
  return;
}

=pod

=item handle

Printer handle.

PARAMS:
RETURNS: $printer_handle

=cut

sub handle {
  my $self = shift;
  unless($self->{handle}) {
    my $tmpdir = ($^O eq 'MSWin32' || $^O eq 'cygwin') ? '/temp' : $ENV{'TMPDIR'} || '/tmp';
    $self->{handle} = File::Temp->new
    (
        DIR => $tmpdir,
        UNLINK => 1,
        TEMPLATE => App::Name->prog_name . '-XXXX'
    );
    if (defined($self->{handle}))
    {
        $self->debug_message("opened tempfile $self->{handle} for lpr", 4);
    }
    else
    {
        $self->error_message("failed to open tempfile for lpr: $!");
        return;
    }
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
  if(my $ref = $self->can('print_' . $type)) {
    return $self->$ref(@_);
  }
  $self->error_message("thought we had a valid type but do not: "
                                 . $type);
   return;
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
