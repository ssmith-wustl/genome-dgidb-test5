package Music::Correlation;

use warnings;
use strict;

=head1 NAME

Music::Correlation - identification of significantly mutated genes

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

## Declare variables ##

my $maf_file = "";		# Mutation table in MAF format
my $reference = "";		# Path to reference FASTA file

## Declare usage statement ##

my $usage = qq{
      USAGE: music.pl correlation OPTIONS
      
      OPTIONS:
      
      --maf-file		List of mutations in MAF format
      --reference		Path to reference FASTA file
      --output-file		Output file to contain results
};

=head1 SYNOPSIS

Identifies significantly mutated genes


=head1 USAGE

      music.pl correlation OPTIONS
      
      OPTIONS:
      
      --maf-file		List of mutations in MAF format
      --reference		Path to reference FASTA file
      --output-file		Output file to contain results      


=head1 FUNCTIONS

=cut

################################################################################

=head2	new

Initializes a new analysis

=cut

################################################################################

sub new {

    ## Get command-line options ##

    my $result = Music::GetOptions (
	"maf-file=s"   => \$maf_file,
	"reference=s"   => \$reference,
    );


    ## Print USAGE and exit if required arguments are not found ##

    if(!$maf_file)
    {
	print $usage;
	return;
    }

    print "Running analysis...\n";

    return(0);
}


################################################################################

=head2	function2

Your description here

=cut

################################################################################

sub function2 {
}

=head1 AUTHOR

The Genome Center at Washington University, C<< <software at genome.wustl.edu> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Music::Correlation

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Music::Correlation
