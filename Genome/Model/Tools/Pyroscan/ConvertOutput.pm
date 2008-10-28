
package Genome::Model::Tools::Pyroscan::ConvertOutput;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# ConvertOutput.pm -	Convert Pyroscan output to refseq coordinates and genotype submission file format
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	10/21/2008 by D.K.
#	MODIFIED:	10/21/2008 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Pyroscan::ConvertOutput {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		input_file	=> { is => 'Text', doc => "Pyroscan output file" },
		headers_file	=> { is => 'Text', doc => "FASTA or FASTA-header file of reference sequence" },
		sample_name	=> { is => 'Text', doc => "Sample name to record for genotype" },		
		output_file	=> { is => 'Text', doc => "Output file" },		
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Convert output to refseq coords and genotype submission format"                 
}

sub help_synopsis {
    return <<EOS
This command uses the header information in the refseq file to translate coordinates, then reformats Pyroscan output to genotype submission format
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
	my $input_file = $self->input_file;
	my $headers_file = $self->headers_file;
	my $sample_name = $self->sample_name;
	my $output_file = $self->output_file;

	## Verify that alignments file exists ##
	
	if(!(-e $input_file))
	{
		print "Input file does not exist. Exiting...\n";
		return(0);
	}	

	## Verify that headers file exists ##
	
	if(!(-e $headers_file))
	{
		print "Headers file does not exist. Exiting...\n";
		return(0);
	}


	## Parse the refseq header ##
	
	my %Amplicons = ParseHeadersFile($headers_file);

	## Get the amplicon name and coordinates ##
	
	my $amplicon_name = my $amplicon_chrom = my $amplicon_chr_start = my $amplicon_chr_stop = "";
	foreach my $amp_name (keys %Amplicons)
	{
		$amplicon_name = $amp_name;
		($amplicon_chrom, $amplicon_chr_start, $amplicon_chr_stop) = split(/\t/, $Amplicons{$amp_name});
	}


	## Open the output file ##
	
	open(OUTFILE, ">$output_file") or die "Can't open outfile: $!\n";


	## Parse the Pyroscan file ##

	my $input = new FileHandle ($input_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		if($line && substr($line, 0, 1) ne '#')
		{
			my @lineContents = split(/\t/, $line);
			my $amplicon_pos = $lineContents[0];
			my $variant_type = $lineContents[1];
			my $ref_allele = $lineContents[3];
			my $reads1 = $lineContents[4];
			(my $variant_code, my $var_allele) = split(/\:/, $lineContents[5]);
			my $reads2 = $lineContents[6];
			my $p_value = $lineContents[8];
			
			## Convert position to genomic ##
			my $chrom = 'C' . $amplicon_chrom;
			my $chr_position = $amplicon_chr_start + $amplicon_pos - 1;
			
			## Build discovery string ##
			
			my $discovery_string = "PyroScan(" . $ref_allele . ":" . $var_allele . ":" . $p_value . ":reads1=$reads1" . ":reads2=$reads2)";
			
			print OUTFILE "B36\t$chrom\t0+\t$chr_position\t$chr_position\t";
			print OUTFILE "$sample_name\t'$ref_allele\t'$var_allele\t$discovery_string\n";
			print "$chrom\t$chr_position\t$discovery_string\n";
		}
	}
	
	close($input);
	
	close(OUTFILE);
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




#############################################################
# ParseHeadersFile - parse headers file 
#
#############################################################

sub ParseHeadersFile
{
	my $FileName = shift(@_);

	my %AmpliconCoords = ();
	my $numAmplicons = 0;

	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		if($lineCounter == 1 && $line && substr($line, 0, 1) eq ">")
		{
			my @lineContents = split(/\s+/, $line);
			my $numContents = @lineContents;
			
			my $amplicon_name = my $amplicon_chrom = my $amplicon_chr_start = my $amplicon_chr_stop = "";
			
			for(my $eCounter = 0; $eCounter < $numContents; $eCounter++)
			{
				if($eCounter == 0)
				{
					$amplicon_name = substr($lineContents[$eCounter], 1, 999);
				}
				if($lineContents[$eCounter] =~ "Chr")
				{
					my @temp = split(/\:/, $lineContents[$eCounter]);
					$amplicon_chrom = $temp[1];
					$amplicon_chrom =~ s/\,//;
				}
				if($lineContents[$eCounter] =~ "Coords")
				{
					($amplicon_chr_start, $amplicon_chr_stop) = split(/\-/, $lineContents[$eCounter + 1]);
					$amplicon_chr_stop =~ s/\,//;
				}
	
			}
	
			if($amplicon_name && $amplicon_chrom && $amplicon_chr_stop && $amplicon_chr_start)
			{
#				$GenesByChrom{$amplicon_chrom} .= "$amplicon_chr_start\t$amplicon_chr_stop\t$amplicon_name\n";
				$AmpliconCoords{$amplicon_name} = "$amplicon_chrom\t$amplicon_chr_start\t$amplicon_chr_stop";
				return(%AmpliconCoords);
			}
		}

	}	
	
#	print "$numAmplicons amplicon coordinate sets parsed from $FileName\n";
	
	warn "Unable to parse amplicon coordinate information from $FileName\n";
	return(%AmpliconCoords);
}



1;

