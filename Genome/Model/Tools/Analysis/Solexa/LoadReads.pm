
package Genome::Model::Tools::Analysis::Solexa::LoadReads;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# LoadReads - Run maq sol2sanger on Illumina/Solexa files in a gerald_directory
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	04/01/2009 by D.K.
#	MODIFIED:	04/01/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Analysis::Solexa::LoadReads {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		flowcell	=> { is => 'Text', doc => "Link to the Gerald directory containing s*_sequence.txt files", is_optional => 1 },
		gerald_dir	=> { is => 'Text', doc => "Link to the Gerald directory containing s*_sequence.txt files", is_optional => 1 },
		output_dir	=> { is => 'Text', doc => "Output file for FastQ files [./]" , is_optional => 1},
		lanes	=> { is => 'Text', doc => "Lanes to include [1,2,3,4,5,6,7,8]", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Obtains reads from a flowcell in FastQ format"                 
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
	my $flowcell = $self->flowcell;
	my $lanes = $self->lanes;
	my $gerald_dir = $self->gerald_dir;
	my $output_dir = $self->output_dir;

	if($flowcell)
	{
		
	}

	if($gerald_dir)
	{	
		if(!(-d $gerald_dir))
		{
			die "Error: Gerald directory does not exist!\n";
		}
	
		## Create the output dir if it does not exist ##
	
		if(!(-d $output_dir))
		{
			mkdir($output_dir);
		}
	
		## Open the directory and find ##
		
		opendir(GERALD_DIR, $gerald_dir) or die "Unable to open gerald directory $gerald_dir\n";
		
		## Identify s_*sequence.txt files ##
	
		my @sequence_files = ();	
		my @dirfiles = readdir GERALD_DIR;
		
		foreach my $filename (sort @dirfiles)
		{
			if(substr($filename, length($filename) - 12, 12) eq "sequence.txt")
			{
				my $outfile = $filename;
				$outfile =~ s/\.txt/\.fastq/;
				my $cmd = "maq sol2sanger $gerald_dir/$filename $output_dir/$outfile";
				print "$cmd\n";
				system("bsub -q long -R\"select[type==LINUX64 && mem>2000] rusage[mem=2000]\" $cmd");
			}
		}
		
		closedir(GERALD_DIR);
	}
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

