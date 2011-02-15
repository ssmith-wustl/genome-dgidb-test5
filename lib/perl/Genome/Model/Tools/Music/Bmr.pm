package Genome::Model::Tools::Music::Bmr;

use warnings;
use strict;
use IO::File;

=head1 NAME

Genome::Model::Tools::Music::Bmr - Calculation of gene coverages and background mutation rates

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

class Genome::Model::Tools::Music::Bmr
{
  is => 'Command',
  has => [ # specify the command's single-value properties (parameters) <---
    maf_file  => { is => 'Text', doc => "List of mutations in MAF format" },
    reference    => { is => 'Text', doc => "Path to reference sequence in FASTA format", is_optional => 1 },
  ],
};

sub sub_command_sort_position { 12 }

# keep this to just a few words <---
sub help_brief
{
  "Calculate gene coverages and background mutation rates"
}

# The usage syntax for this command
sub help_synopsis
{
  return <<EOS
This command identifies significantly mutated genes
EXAMPLE:  gmt music smg --maf-file myMAF.tsv
EOS
}

# this is what the user will see with the longer version of help. <---
sub help_detail
{
  return <<EOS

EOS
}

=head1 SYNOPSIS

Calculate gene coverages per sample, per gene, and per mutation category

=head1 USAGE

  music.pl smg OPTIONS

  OPTIONS:

  --maf-file    List of mutations in MAF format
  --reference    Path to reference FASTA file
  --output-file    Output file to contain results


=head1 FUNCTIONS

=cut

################################################################################

=head2  execute

Initializes a new analysis

=cut

################################################################################

sub execute
{
    my $self = shift;

    print "Running analysis...\n";

    return(0);
}


################################################################################

=head2  function2

Your description here

=cut

################################################################################

sub function2
{
}

=head1 AUTHOR

The Genome Center at Washington University, C<< <software at genome.wustl.edu> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Genome::Music::SMG

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Genome::Music::SMG
