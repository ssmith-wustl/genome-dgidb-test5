#
# This is a trivial "sleep" suite for testing.
#

package Genome::Model::Tools::LSFSpool::Sleep;

use warnings;
use strict;
use Genome::Model::Tools::LSFSpool::Error;

sub create() {
  my $class = shift;
  my $self = {
    parent => shift,
  };

  # for sleep, parameters is the time to sleep, an integer number of seconds
  $self->error("'parameters' unspecified in parent object suite\n")
      if (! defined $self->{parent}->{config}->{suite}->{parameters});

  $self->{parameters} = $self->{parent}->{config}->{suite}->{parameters};

  bless $self, $class;
  return $self;
}

sub error {
  # Raise an Exception object.
  my $self = shift;
  Genome::Model::Tools::LSFSpool::Error->throw( error => @_ );
}

sub logger {
  my $self = shift;
  my $fh = $self->{parent}->{logfh};
  print $fh localtime() . ": @_";
}

sub local_debug {
  my $self = shift;
  $self->logger("DEBUG: @_")
    if ($self->{parent}->{debug});
}

sub action {
  my $self = shift;

  # This is the action certified for this suite.
  # It will be run by the caller.
  return "sleep $self->{parameters}";
}

sub is_complete {
  # Test if command completed correctly.
  # return 0 if invalid, 1 if valid

  # Always return 0, this means we're never complete and we always sleep.
  return 0;
}

1;

__END__

=pod

=head1 NAME

Genome::Model::Tools::LSFSpool::Sleep - A trivial LSFSpool command Suite implementing sleep.

=head1 SYNOPSIS

  use Genome::Model::Tools::LSFSpool::Sleep
  my $suite = create Genome::Model::Tools::LSFSpool::Sleep

=head1 DESCRIPTION

This simple command suite allows for unit testing of LSFSpools spooling mechanism.

=head1 CLASS METHODS

=over

=item create()

Instantiates the class.

=item logger()

Sleep class' logger().

=item local_debug()

Sleep class' debugging.

=item action()

Performs a simple "sleep N" in the current spooldir.

=item is_complete()

Returns true.

=back

=head1 AUTHOR

Matthew Callaway (mcallawa@genome.wustl.edu)

=head1 COPYRIGHT

Copyright (c) 2010, Washington University Genome Center. All Rights Reserved.

This module is free software. It may be used, redistributed and/or modified
under the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)

=cut
