
package Genome::Model::Tools::Analysis::454::AlignReads;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# AlignReads - Align reads with SSAHA2 or other aligner
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

class Genome::Model::Tools::Analysis::454::AlignReads {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		samples_file	=> { is => 'Text', doc => "Tab-delimited file of sample and SFF file(s)" },
		output_dir	=> { is => 'Text', doc => "Output directory" },
		aligner		=> { is => 'Text', doc => "Aligner to use" },
		reference		=> { is => 'Text', doc => "Reference sequence [default=Hs36 ssaha2]", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Align 454 reads using FASTA locations from samples.tsv"                 
}

sub help_synopsis {
    return <<EOS
This command loads 454 data from a samples.tsv file and alignments
EXAMPLE:	gmt analysis 454 align-reads --samples-file data/samples.tsv --output-dir data --aligner ssaha2
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
	my $samples_file = $self->samples_file;
	my $output_dir = $self->output_dir;
	my $aligner = $self->aligner;

	if(!(-e $samples_file))
	{
		die "Error: Samples file not found!\n";
	}

	my $input = new FileHandle ($samples_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		my @lineContents = split(/\t/, $line);			
		my $sample_name = $lineContents[0];
		my $sff_files = $lineContents[1];				
		
		## Create sample output directories ##
		my $sample_output_dir = $output_dir . "/" . $sample_name;
		my $sff_dir = $sample_output_dir . "/sff";
		my $fasta_dir = $sample_output_dir . "/fasta_dir";
		my $fasta_file = "$fasta_dir/$sample_name.fasta";
		my $quality_file = "$fasta_dir/$sample_name.fasta.qual";
		my $aligner_output_dir = $sample_output_dir . "/" . $aligner . "_out";
		mkdir($aligner_output_dir) if(!(-d $aligner_output_dir));
		
		
		if(-e $fasta_file)
		{
			if($aligner eq "ssaha2")
			{
				my $aligner_output_file = "$aligner_output_dir/$sample_name.$aligner.sam";

				## Declare command object ##
				my $cmd_obj;

				if($self->reference)
				{
					$cmd_obj = Genome::Model::Tools::Ssaha::AlignToGenome->create(
					    query_file => $fasta_file,
					    output_file => $aligner_output_file,
					    reference => $self->reference,
					);					
				}
				else
				{
					$cmd_obj = Genome::Model::Tools::Ssaha::AlignToGenome->create(
					    query_file => $fasta_file,
					    output_file => $aligner_output_file,
					);					
				}
	
		                $cmd_obj->execute;
                #my $cmd = "gmt ssaha align-to-genome --query-file $fasta_file --output-file $aligner_output_file";
                #system($cmd);
			}
		}
		else
		{
			die "Fasta file $fasta_file not found!\n";
		}
		
	}
	
	close($input);

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

