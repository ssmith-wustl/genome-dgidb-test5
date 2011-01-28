
package Genome::Model::Tools::BioDbFasta::Convert;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# Convert.pm - 		Convert Phred-like quality values to ASCII equivalents for use with Build a Bio::DB::Fasta
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	10/15/2008 by D.K.
#	MODIFIED:	10/16/2008 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use Bio::DB::Fasta;
use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::BioDbFasta::Convert {
    is => 'Command',                       
    has => [                                # specify the command's single-value properties (parameters) <--- 
        infile      => { is => 'Text',       doc => "Input file of quality scores" },
        outfile      => { is => 'Text',       doc => "Output file of FASTQ values" },        

    ], 
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Convert quality scores to maq-like FASTQ format"                 
}

sub help_synopsis {                         # replace the text below with real examples <---
    return <<EOS
This command converts a phred-like quality file (.qual) to maq-like FASTQ format (.qual.fa)
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 
Example:
 gmt convert --infile myQuals.qual --outfile myQuals.qual.fa

Numeric quality values, such as those generated by Phred, take up multiple character spaces:
 >myQuals
 15 15 20 28 28 29 31 31 28 28 24 22 19 14 7

These will be converted to their ASCII equivalents, which take up a single character space:
 >myQuals
 005==?@@==974/(
EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;
	
	if(!(-e $self->infile))
	{
		print "Input file does not exist. Exiting...\n";
		return(0);	
	}
	
	my $input = new FileHandle ($self->infile);
	
	open(OUTFILE, ">" . $self->outfile) or die "Can't open outfile: $!\n";
	
	my $lineCounter = 0;
	my $record_name = my $record_seq = "";
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	

			if(substr($line, 0, 1) eq ">")
			{
				if($record_name && $record_seq)
				{
#					printQualString($record_name, $record_seq);
					my $qual_string = $self->getQualString($record_seq);
					print OUTFILE ">$record_name\n$qual_string\n";				
				}				
				
				$record_name = $record_seq = "";
				
				$record_name = substr($line, 1, 999);	
			}
			else
			{
				$record_seq .= " " if($record_seq);				
				$record_seq .= $line;
			}

	}

	if($record_name && $record_seq)
	{
#		printQualString($record_name, $record_seq);
		my $qual_string = $self->getQualString($record_seq);
		print OUTFILE ">$record_name\n$qual_string\n";
	}
	
	close(OUTFILE);

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}

#############################################################
# printQualString - convert numeric to ASCII qual values
#
#############################################################

sub getQualString
{
    my $self = shift;
    my $record_seq = shift;
	
	my @qualValues = split(/\s+/, $record_seq);
	my $numValues = @qualValues;
	
	my $record_squal = "";
	
	for(my $vCounter = 0; $vCounter < $numValues; $vCounter++)
	{
		my $Q = $qualValues[$vCounter];
		$Q-- if($Q == 29); ## Fix the problematic value corresponding to '>' ##
		my $Qchar = chr(($Q<=93? $Q : 93) + 33);
		$record_squal .= "$Qchar";
	}
	
	return($record_squal);
}

1;

