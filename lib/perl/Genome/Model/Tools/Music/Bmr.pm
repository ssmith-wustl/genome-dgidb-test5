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
  is => 'Command::Tree',
};

sub sub_command_sort_position { 12 }

# keep this to just a few words <---
sub help_brief
{
  "Tools to calculate gene coverages and background mutation rates"
}

# The usage syntax for this command
sub help_synopsis
{
  return <<EOS

EOS
}

# this is what the user will see with the longer version of help. <---
sub help_detail
{
  return <<EOS

EOS
}

=head1 SYNOPSIS

Tools to calculate gene coverages and background mutation rates

=cut

=head1 AUTHOR

The Genome Center at Washington University, C<< <software at genome.wustl.edu> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Genome::Music::Bmr

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Genome::Music::Bmr
