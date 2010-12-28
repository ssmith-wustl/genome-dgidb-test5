package Genome::Model::Tools::Music::PathScan;

use warnings;
use strict;

=head1 NAME

Genome::Music::PathScan - identification of significantly mutated genes

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

class Genome::Model::Tools::Music::PathScan {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		maf_file	=> { is => 'Text', doc => "List of mutations in MAF format" },
		reference		=> { is => 'Text', doc => "Path to reference sequence in FASTA format", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Perform pathway analysis on a list of mutations"                 
}

sub help_synopsis {
    return <<EOS
This command performs pathway analysis on a list of mutations
EXAMPLE:	gmt music pathway --maf-file myMAF.tsv
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

EOS
}


=head1 SYNOPSIS

Identifies significantly mutated genes


=head1 USAGE

      music.pl pathway OPTIONS
      
      OPTIONS:
      
      --maf-file		List of mutations in MAF format
      --reference		Path to reference FASTA file
      --output-file		Output file to contain results      


=head1 FUNCTIONS

=cut

################################################################################

=head2	execute

Initializes a new analysis

=cut

################################################################################

sub execute {
    my $self = shift;

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

    perldoc Genome::Music::PathScan

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Genome::Music::PathScan
