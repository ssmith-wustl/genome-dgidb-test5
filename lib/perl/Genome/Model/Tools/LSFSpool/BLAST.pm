#
# This is a Suite to return a particular BLASTX command.
#

use strict;
use warnings;
use Fcntl;
use Genome::Model::Tools::LSFSpool::Error;

package Genome::Model::Tools::LSFSpool::BLAST;

sub create {
  my $class = shift;

  # NOTE: This is where we set the "certified" blastx command.
  my $self = {
    parent => shift,
    blastx => '/gsc/bin/blastxplus-2.2.23',
  };

  # Validate the parameters for blastx that were specified in the config file.
  $self->error("'parameters' unspecified in parent object suite\n")
    if (! defined $self->{parent}->{config}->{suite}->{parameters});

  $self->{parameters} = $self->{parent}->{config}->{suite}->{parameters};

  return bless $self, $class;
}

sub error {
  # Raise and Exception object.
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
  # Produce the formatted command string that will be executed by the caller.
  my $self = shift;
  my $spooldir = shift;
  # Note this input file may have LSB_JOBINDEX in it,
  # making it not really a real filename, so don't test it with -f.
  my $inputfile = shift;

  $self->error("given spool is not a directory: $spooldir\n")
    if (! -d $spooldir);

  $self->local_debug("action($spooldir,$inputfile)\n");
  my $outputfile = "/tmp/" . $inputfile . "-output";
  $inputfile = $spooldir . "/" . $inputfile;

  # This is the action certified for this suite.
  # This is hard coded for security reasons.
  return "$self->{blastx} $self->{parameters} -query $inputfile -out $outputfile";
}

sub is_complete ($) {
  # Test if command completed correctly.
  # return 1 if complete, 0 if not
  use File::Basename;

  my $self = shift;
  my $infile = shift;

  # blastx creates output files with some number of reads in them but it may
  # include a given read more than once, or not at all.  So, we just ensure
  # non-empty output and trust that if blastx exits zero, then we're ok.
  my $inquery = $self->count_query(">", $infile);
  my $outquery = $self->read_output("$infile-output");

  if (! defined $outquery ) {
    return 0;
  }
  if ( $inquery != $outquery ) {
    return 0;
  }
  if ( ! -f "$infile-output" or -s "$infile-output" == 0 ) {
    return 0;
  }

  return 1;
}

sub read_output {
  # Read the blastx output file and parse one of several possible output
  # formats.  Return the number of reads represented in the output.
  my $self = shift;
  my $filename = shift;

  my $parameters = $self->{parameters};

  $self->local_debug("read_output($filename)\n");
  my $format = 0;

  if ($parameters =~ m/.*outfmt\s\"(.*)\"/) {
    my @toks = split(/ /,$1);
    $format = $toks[0];
  } else {
    # no format specified, use the default
    $format = 0;
  }

  $self->local_debug("output format: $format\n");
  if ($format == 7) {
    return $self->outfmt_7($filename);
  } elsif ($format == 0) {
    return $self->outfmt_0($filename);
  } else {
    $self->error("Unsupported blastx output format: $format\n");
  }
}

sub outfmt_0 {
  # Format 0 is blastx's default verbose text output.
  # A line with Query= indicates an input read's output block.
  my $self = shift;
  my $filename = shift;
  return $self->count_query("Query=",$filename);
}

sub outfmt_7 {
  # Format 7 is blastx's tabular format.  It includes a comment
  # at the end that contains the total number of reads.
  my $self = shift;
  my $filename = shift;

  # We want to 'slurp' the file and read the end of it.
  my $buf = '';
  my $buf_ref = \$buf;
  my $mode = Fcntl::O_RDONLY;

  local *FH ;
  local $/;

  # Return 0 so caller gets 'incomplete'.
  sysopen FH, $filename, $mode or
    return 0;

  # Seek to end of file minus some and read it.
  # Assumes that one line will fit into "blocksize".
  my $blocksize = 100;
  sysseek FH, -$blocksize, 2 or return 0;
  sysread FH, ${$buf_ref}, $blocksize or return 0;
  close FH ;

  my $res;
  if ($buf =~ m/processed (\d+) queries/) {
    $res = $1;
  }
  return $res;
}

sub count_query {
  # Parse a file and count occurences of $query.
  my $self = shift;
  my $query = shift;
  my $filename = shift;

  $self->local_debug("count_query($query,$filename)\n");

  # We want to 'slurp' to be maximally efficient.
  my $buf = '';
  my $buf_ref = \$buf;
  my $mode = Fcntl::O_RDONLY;

  local *FH ;

  # Return 0 so caller gets 'incomplete'.
  sysopen FH, $filename, $mode or
    return 0;

  local $/;

  my $size_left = -s FH;
  $self->local_debug("size $size_left\n");

  my $count = 0;
  while( $size_left > 0 ) {

    my $read_cnt = sysread( FH, ${$buf_ref}, $size_left, length ${$buf_ref} );

    return 0 unless( $read_cnt );

    my $last = 0;
    my $idx = 0;
    while ($idx != -1) {
      $idx = index(${$buf_ref},$query,$last);
      $last = $idx + 1;
      $count++ if ($idx != -1);
    }

    $size_left -= $read_cnt;
  }
  $self->local_debug("count_query($query,$filename) = $count\n");
  close(FH);
  return $count;
}

1;

__END__

=pod

=head1 NAME

BLAST - One of several possible Suite classes.

=head1 SYNOPSIS

  use Genome::Model::Tools::LSFSpool::Suite;
  my $class = new Genome::Model::Tools::LSFSpool::Suite->create("BLAST");

=head1 DESCRIPTION

This class represents the ability to run "blastx" as a "certified" program.
Here we define how blast is called, and how we validate the output.

=head1 CLASS METHODS

=over

=item create()

Instantiates the class.

=item logger($)

Error class' logger().  Log a line.

=item local_debug($)

Error class' debugging.  Log a line if debug is true.

=item action()

Returns the command string for blastx.

=item is_complete()

Returns true if the input file has the same number of DNA sequence reads
as the corresponding output file.

=back

=head1 AUTHOR

Matthew Callaway (mcallawa@genome.wustl.edu)

=head1 COPYRIGHT

Copyright (c) 2010, Washington University Genome Center. All Rights Reserved.

This module is free software. It may be used, redistributed and/or modified
under the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)

=cut

