
package Genome::Model::Tools::Capture::CreateMafFile;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# CreateMafFile - Build Genome Models for Capture Datasets
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	12/09/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

## Declare global statistics hash ##

my %stats = ();

class Genome::Model::Tools::Capture::CreateMafFile {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		snv_file	=> { is => 'Text', doc => "File of SNVs to include", is_optional => 0, is_input => 1},
		snv_annotation_file	=> { is => 'Text', doc => "File of SNVs to include", is_optional => 0, is_input => 1 },
		somatic_status => { is => 'Text', doc => "Predicted somatic status of variant (Germline/Somatic/LOH) [Somatic]", is_optional => 1, is_input => 1},
		indel_file	=> { is => 'Text', doc => "File of SNVs to include", is_optional => 1 },
		indel_annotation_file	=> { is => 'Text', doc => "File of SNVs to include", is_optional => 1 },
		genome_build	=> { is => 'Text', doc => "Reference genome build used for coordinates [36]", is_optional => 1 },
		phase	=> { is => 'Text', doc => "Project Phase [Phase_IV]", is_optional => 1 },
		tumor_sample	=> { is => 'Text', doc => "Tumor sample name [Tumor]", is_optional => 1 },
		normal_sample	=> { is => 'Text', doc => "Normal sample name [Normal]", is_optional => 1 },
		source	=> { is => 'Text', doc => "Library source (PCR/Capture) [Capture]", is_optional => 1 },
		platform	=> { is => 'Text', doc => "Sequencing platform [Illumina GAIIx]", is_optional => 1 },
		center	=> { is => 'Text', doc => "Sequencing center [genome.wustl.edu]", is_optional => 1 },
		output_file	=> { is => 'Text', doc => "Output file for MAF format", is_optional => 0, is_input => 1, is_output => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Build MAF files for predicted variants from capture projects"                 
}

sub help_synopsis {
    return <<EOS
Build MAF files for predicted variants from capture projects
EXAMPLE:	gmt capture build-models ...
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
	
	my $snv_file = $self->snv_file;
	my $snv_annotation_file = $self->snv_annotation_file;
	my $output_file = $self->output_file;
	my $indel_file = $self->indel_file;
	my $indel_annotation_file = $self->indel_annotation_file;

	## Declare parameter defaults ##

	my $genome_build = "36";
	my $phase = "Phase_IV";
	my $source = "Capture";
	my $platform = "Illumina GAIIx";
	my $center = "genome.wustl.edu";
	my $somatic_status = "Somatic";
	my $tumor_sample = "Tumor";
	my $normal_sample = "Normal";

	## Change any user-provided parameters ##

	$genome_build = $self->genome_build if($self->genome_build);
	$phase = $self->phase if($self->phase);
	$source = $self->source if($self->source);
	$platform = $self->platform if($self->platform);
	$somatic_status = $self->somatic_status if($self->somatic_status);
	$center = $self->center if($self->center);
	$tumor_sample = $self->tumor_sample if($self->tumor_sample);
	$normal_sample = $self->normal_sample if($self->normal_sample);
	

	## Verify existence of files ##

	if(!(-e $snv_file && -e $snv_annotation_file))
	{
		warn "Error: SNV file or SNV annotation file does not exist!\n";
		return 0;
	}

	## Open the outfile ##
	
	open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";
	print OUTFILE "Hugo_Symbol\tEntrez_Gene_Id\tCenter\tNCBI_Build\tChromosome\tStart_position\tEnd_position\tStrand\tVariant_Classification\tVariant_Type\tReference_Allele\tTumor_Seq_Allele1\tTumor_Seq_Allele2\tdbSNP_RS\tdbSNP_Val_Status\tTumor_Sample_Barcode\tMatched_Norm_Sample_Barcode\tMatch_Norm_Seq_Allele1\tMatch_Norm_Seq_Allele2\tTumor_Validation_Allele1\tTumor_Validation_Allele2\tMatch_Norm_Validation_Allele1\tMatch_Norm_Validation_Allele2\tVerification_Status\tValidation_Status\tMutation_Status\tSequencing_Phase\tSequence_Source\tValidation_Method\tScore\tBAM_file\tSequencer\n";		


	## Load the annotations ##
	
	my %annotations = load_annotations($snv_annotation_file);
	
	
	## Parse the SNV file ##
	
	## Parse the variant file ##

	my $input = new FileHandle ($snv_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		my @lineContents = split(/\t/, $line);			

		my $chrom = $lineContents[0];
		my $chr_start = $lineContents[1];
		my $chr_stop = $lineContents[2];
		my $ref = $lineContents[3];
		my $var = $lineContents[4];

		my $key = "$chrom\t$chr_start\t$chr_stop\t$ref\t$var";	

		if($annotations{$key})
		{
			(my $var_type, my $gene, my $trv_type) = split(/\t/, $annotations{$key});

			my $maf_line = "";

			$maf_line .=  "$gene\t0\t$center\t$genome_build\t$chrom\t$chr_start\t$chr_stop\t+\t";
			$maf_line .=  "$trv_type\t$var_type\t$ref\t";
			$maf_line .=  "$var\t$var\t";
			$maf_line .=  "\t\t"; #dbSNP
			$maf_line .=  "$tumor_sample\t$normal_sample\t$ref\t$ref\t";
			$maf_line .=  "\t\t\t\t"; # Validation alleles
			$maf_line .=  "Unknown\tUnknown\tSomatic\t";
			$maf_line .=  "$phase\tCapture\t";
			$maf_line .=  "\t"; # Val method
			$maf_line .=  "1\t"; # Score
			$maf_line .=  "dbGAP\t";
			$maf_line .=  "$platform\n";			

			print OUTFILE "$maf_line";
		}
	}
	
	close($input);
	
	
	
	## Load the annotations ##
	
	%annotations = load_annotations($indel_annotation_file);
	
	
	## Parse the Indel file ##
	
	## Parse the variant file ##

	$input = new FileHandle ($indel_file);
	$lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		my @lineContents = split(/\t/, $line);			

		my $chrom = $lineContents[0];
		my $chr_start = $lineContents[1];
		my $chr_stop = $lineContents[2];
		my $ref = $lineContents[3];
		my $var = $lineContents[4];

		my $key = "$chrom\t$chr_start\t$chr_stop\t$ref\t$var";	

		if($annotations{$key})
		{
			(my $var_type, my $gene, my $trv_type) = split(/\t/, $annotations{$key});

			my $maf_line = "";

			$maf_line .=  "$gene\t0\t$center\t$genome_build\t$chrom\t$chr_start\t$chr_stop\t+\t";
			$maf_line .=  "$trv_type\t$var_type\t$ref\t";
			$maf_line .=  "$var\t$var\t";
			$maf_line .=  "\t\t"; #dbSNP
			$maf_line .=  "$tumor_sample\t$normal_sample\t$ref\t$ref\t";
			$maf_line .=  "\t\t\t\t"; # Validation alleles
			$maf_line .=  "Unknown\tUnknown\tSomatic\t";
			$maf_line .=  "$phase\tCapture\t";
			$maf_line .=  "\t"; # Val method
			$maf_line .=  "1\t"; # Score
			$maf_line .=  "dbGAP\t";
			$maf_line .=  "$platform\n";			

			print OUTFILE "$maf_line";
		}
	}
	
	close($input);
		
	
	
	close(OUTFILE);
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}









#############################################################
# parse_file - takes input file and parses it
#
#############################################################

sub load_annotations
{
	my $annotation_file = shift(@_);

	## Parse the annotation file ##

	my %annotations = ();

	my $input = new FileHandle ($annotation_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		my @lineContents = split(/\t/, $line);			
		my $chrom = $lineContents[0];
		my $chr_start = $lineContents[1];
		my $chr_stop = $lineContents[2];
		my $ref = $lineContents[3];
		my $var = $lineContents[4];
		my $var_type = $lineContents[5];		
		my $gene_name = $lineContents[6];

		my $trv_type = $lineContents[13];
		
		my $key = "$chrom\t$chr_start\t$chr_stop\t$ref\t$var";
		
		$annotations{$key} = "$var_type\t$gene_name\t$trv_type";

	}

	close($input);

	return(%annotations);

}



1;

