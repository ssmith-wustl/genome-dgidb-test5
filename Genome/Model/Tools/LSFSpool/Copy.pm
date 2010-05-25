
#
# This is a trivial Copy suite for unit testing.
#

package Genome::Model::Tools::LSFSpool::Copy;

use warnings;
use strict;
use Genome::Model::Tools::LSFSpool::Error;

sub create() {
  my $class = shift;
  my $self = {
    parent => shift,
  };

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
  my $spooldir = shift;
  my $inputfile = shift;

  $inputfile = $spooldir . "/" . $inputfile;

  $self->error("given spool is not a directory: $spooldir\n")
    if (! -d $spooldir);

  # This is the copy action certified for this suite.
  return "cp $self->{parameters} $inputfile $inputfile-output";
}

sub is_complete {
  # Test if command completed correctly.
  # return 0 if invalid, 1 if valid
  use File::Compare;

  my $self = shift;
  my $infile = shift;

  my $result = compare($infile,"$infile-output");
  if ( $result != 0 ) {
    $self->local_debug("Input file $infile returns incomplete: $result\n");
    return 0;
  }

  return 1;
}

1;

__END__

=pod

=head1 NAME

Genome::Model::Tools::LSFSpool::Copy - A trivial LSFSpool command Suite implementing cp(1).

=head1 SYNOPSIS

  use Genome::Model::Tools::LSFSpool::Copy
  my $suite = create Genome::Model::Tools::LSFSpool::Copy

=head1 DESCRIPTION

This simple command suite allows for unit testing of LSFSpools spooling
mechanism.

=head1 CLASS METHODS

=over

=item create()

Instantiates the class.

=item logger()

Copy class' logger().

=item local_debug()

Copy class' debugging.

=item action()

Performs a simple "cp $inputfile ${inputfile}-output" in the current spooldir.

=item is_complete()

Returns true if the input file matches the outputfile.

=back

=head1 AUTHOR

Matthew Callaway (mcallawa@genome.wustl.edu)

=head1 COPYRIGHT

Copyright (c) 2010, Washington University Genome Center. All Rights Reserved.

This module is free software. It may be used, redistributed and/or modified
under the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)

=cut
