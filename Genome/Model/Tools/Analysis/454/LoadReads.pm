
package Genome::Model::Tools::Analysis::454::LoadReads;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# LoadReads - Load 454 reads from a sample-SFF tab-delimited file
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	02/25/2009 by D.K.
#	MODIFIED:	02/25/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Analysis::454::LoadReads {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		query_file	=> { is => 'Text', doc => "Illumina/Solexa reads in FASTQ format" },
		output_file	=> { is => 'Text', doc => "Output file for Bowtie alignments" },
                reference	=> { is => 'Text', doc => "Path to bowtie-indexed reference [Defaults to Hs36]", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Align reads to a reference genome using Bowtie"                 
}

sub help_synopsis {
    return <<EOS
This command retrieves the locations of unplaced reads for a given genome model
EXAMPLE:	gt bowtie --query-file s_1_sequence.fastq --output-file s_1_sequence.Hs36.bowtie
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;

	## Get required parameters ##
	my $query_file = $self->query_file;
	my $output_file = $self->output_file;

	if(!(-e $query_file))
	{
		die "Error: Query file not found!\n";
	}

	## Define Bowtie Reference (default to Hs36)

	my $reference = "/gscmnt/sata194/info/sralign/dkoboldt/human_refseq/Hs36_1c_dkoboldt.bowtie";

        if(defined($self->reference))
	{
		if(-e $self->reference)
		{
			$reference = $self->reference;
		}
		else
		{
			die "Error: Reference file not found!\n";
		}
	}

	print "Aligning $query_file to $reference\n";
	system("bsub -q long -R\"select[type==LINUX64 && mem>4000] rusage[mem=4000]\" -oo $output_file.log bowtie -m 1 $reference $query_file $output_file");

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

