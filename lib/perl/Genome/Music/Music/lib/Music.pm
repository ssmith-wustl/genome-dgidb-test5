package Music;

use warnings;
use strict;
use Getopt::Long;

=head1 NAME

Music.pm - Shared functions for the MUSIC analysis package

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

## Bring in the Music sub-modules ##

use Music::Correlation;
use Music::CosmicOmim;
use Music::MutationRelation;
use Music::Pathway;
use Music::Proximity;
use Music::SMG;

=head1 SYNOPSIS

Mutation SIgnificance In Cancer (MUSIC) is a comprehensive analysis suite for mutations in cancer genomes

=head1 FUNCTIONS

=cut

################################################################################

=head2	new

Initializes a new analysis

=cut

################################################################################

sub new {

    my $usage = qq{USAGE: music.pl [COMMAND]
            AVAILABLE COMMANDS:
	    play            	Perform all analyses in sequential order
	    proximity       	Identify mutations in close amino acid proximity
	    cosmic-omim     	Compare to COSMIC and OMIM databases
	    smg             	Identify significantly mutated genes
	    pathway         	Identify significantly altered pathways
	    mutation-relation	Perform mutation relationship analyses
	    correlation     	Correlate mutations to clinical/phenotype data    
};

    ## Get the command or else print usage ##
    
    if($ARGV[0])
    {
	my $command = $ARGV[0];

	if($command eq "play")
	{
	    Music::Proximity->new();
	    Music::CosmicOmim->new();
	    Music::SMG->new();
	    Music::Pathway->new();
	    Music::MutationRelation->new();
	    Music::Correlation->new();
	}
	elsif($command eq "proximity")
	{
	    Music::Proximity->new();
	}
	elsif($command eq "cosmic-omim")
	{
	    Music::CosmicOmim->new();
	}
	elsif($command eq "smg")
	{
	    Music::SMG->new();
	}
	elsif($command eq "pathway")
	{
	    Music::Pathway->new();
	}
	elsif($command eq "mutation-relation")
	{
	    Music::MutationRelation->new();
	}
	elsif($command eq "correlation")
	{
	    Music::Correlation->new();
	}	
	else
	{
	    ## Handle an unrecognized command ##
	    warn "Command \'$command\' not recognized!\n";
	    print $usage;
	    return(0);
	}
    }
    else
    {
	print $usage;
	return(0);
    }
}


=head1 AUTHOR

The Genome Center at Washington University, C<< <software at genome.wustl.edu> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Music::SMG

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Music
