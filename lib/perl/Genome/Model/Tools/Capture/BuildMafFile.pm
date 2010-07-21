
package Genome::Model::Tools::Capture::BuildMafFile;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# BuildMafFile - Generate MAF File using Capture Somatic Results
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	06/16/2010 by D.K.
#	MODIFIED:	06/16/2010 by D.K.
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

class Genome::Model::Tools::Capture::BuildMafFile {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		data_dir		=> { is => 'Text', doc => "ID of model group" , is_optional => 0},
		tumor_sample	=> { is => 'Text', doc => "Name of the tumor sample" , is_optional => 0},
		normal_sample	=> { is => 'Text', doc => "Name of the matched normal control" , is_optional => 0},
		output_file	=> { is => 'Text', doc => "Optional output file for paired normal-tumor model ids" , is_optional => 0},
		build 		=> { is => 'Text', doc => "Reference genome build" , is_optional => 1, default => "36"},
		center 		=> { is => 'Text', doc => "Genome center name" , is_optional => 1, default => "genome.wustl.edu"},
		sequence_phase	=> { is => 'Text', doc => "Sequencing phase" , is_optional => 1, default => "Phase_IV"},
		sequence_source	=> { is => 'Text', doc => "Sequence source" , is_optional => 1, default => "Capture"},
		sequencer	=> { is => 'Text', doc => "Sequencing platform name" , is_optional => 1, default => "IlluminaGAIIx"},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Build TCGA-friendly MAF file using somatic capture pipeline output"                 
}

sub help_synopsis {
    return <<EOS
Build TCGA-friendly MAF file using somatic capture pipeline output
EXAMPLE:	gmt capture build-maf-file
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

	my $data_dir = $self->data_dir;
	my $tumor_sample = $self->tumor_sample;
	my $normal_sample = $self->normal_sample;
	my $output_file = $self->output_file;
	
	my $center = $self->center;
	my $build = $self->build;
	my $sequence_phase = $self->sequence_phase;
	my $sequence_source = $self->sequence_source;
	my $sequencer = $self->sequencer;
	
	## Keep stats in a single hash ##
	
	my %stats = ();
	

	## Check for required files in the data directory ##
	
	my $snv_tier1_file = $data_dir . "/" . "merged.somatic.snp.filter.novel.tier1";
	my $snv_annotation_file = $data_dir . "/" . "annotation.somatic.snp.transcript";
	my $indel_tier1_file = $data_dir . "/" . "merged.somatic.indel.tier1";
	my $indel_annotation_file = $data_dir . "/" . "annotation.somatic.indel.transcript";

	if(-e $snv_tier1_file && -e $snv_annotation_file && -e $indel_tier1_file && -e $indel_annotation_file)
	{
		## Open the outfile ##
		
		open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";
		print OUTFILE join("\t", "Hugo_Symbol","Entrez_Gene_Id","Center","NCBI_Build","Chromosome","Start_position","End_position","Strand","Variant_Classification","Variant_Type","Reference_Allele","Tumor_Seq_Allele1","Tumor_Seq_Allele2","dbSNP_RS","dbSNP_Val_Status","Tumor_Sample_Barcode","Matched_Norm_Sample_Barcode","Match_Norm_Seq_Allele1","Match_Norm_Seq_Allele2","Tumor_Validation_Allele1","Tumor_Validation_Allele2","Match_Norm_Validation_Allele1","Match_Norm_Validation_Allele2","Verification_Status","Validation_Status","Mutation_Status","Sequencing_Phase","Sequence_Source","Validation_Method","Score","BAM_file","Sequencer","chromosome_name_WU","start_WU","stop_WU","reference_WU","variant_WU","type_WU","gene_name_WU","transcript_name_WU","transcript_species_WU","transcript_source_WU","transcript_version_WU","strand_WU","transcript_status_WU","trv_type_WU","c_position_WU","amino_acid_change_WU","ucsc_cons_WU","domain_WU","all_domains_WU","deletion_substructures_WU") . "\n";


		## Load the SNVs ##
		
		my %snvs = load_mutations($snv_tier1_file);
		my %snv_annotation = load_annotation($snv_annotation_file);

		foreach my $key (sort byChrPos keys %snvs)
		{
			$stats{'tier1_snvs'}++;
			
			my ($chromosome, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $key);
			my $snv = $snvs{$key};
			my $strand = "+";
			
			my @temp = split("\t", $snv);
			
			my $tumor_cns = $temp[4];
			$tumor_cns = $temp[12] if($temp[11] =~ '%');		

			my $tumor_genotype = iupac_to_genotype($ref, $tumor_cns);
			my ($tumor_gt_allele1, $tumor_gt_allele2) = split(//, $tumor_genotype);


			if($snv_annotation{$key})
			{
				my @annotation = split(/\t/, $snv_annotation{$key});
				my $gene_name = $annotation[6];
				my $gene_id = 0;
				
				my $trv_type = $annotation[13];

				my $mutation_type = trv_to_mutation_type($trv_type);

				my $dbsnp_rs = my $dbsnp_status = "";
				print OUTFILE join("\t", $gene_name,$gene_id,$center,$build,$chromosome,$chr_start,$chr_stop,$strand,$mutation_type,"SNP",$ref,$tumor_gt_allele1,$tumor_gt_allele2,$dbsnp_rs,$dbsnp_status,$tumor_sample,$normal_sample,$ref,$ref,"","","","","Unknown","Unknown","Somatic",$sequence_phase,$sequence_source,"","1","dbGAP",$sequencer, @annotation) . "\n";				

			}
			else
			{
				warn "No annotation for $key in $snv_annotation_file!\n";
			}
		}

		close(OUTFILE);
	}
	else
	{
		die "Tier 1 or Annotation files were missing from $data_dir!\n";
	}


	print $stats{'tier1_snvs'} . " tier 1 SNVs\n";
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub load_mutations
{  
	my $variant_file = shift(@_);
	my $input = new FileHandle ($variant_file);
	my $lineCounter = 0;

	my %mutations = ();

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);
	
		$var = iupac_to_base($ref, $var);
	
		my $key = join("\t", $chromosome, $chr_start, $chr_stop, $ref, $var);
		
		$mutations{$key} = $line;		
	}
	
	close($input);


	return(%mutations);
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub load_annotation
{  
	my $variant_file = shift(@_);
	my $input = new FileHandle ($variant_file);
	my $lineCounter = 0;

	my %annotation = ();

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);

		my $key = join("\t", $chromosome, $chr_start, $chr_stop, $ref, $var);
		
		$annotation{$key} = $line;		
	}
	
	close($input);


	return(%annotation);
}






#############################################################
# IUPAC to base - convert IUPAC code to variant base
#
#############################################################

sub iupac_to_base
{
	(my $allele1, my $allele2) = @_;
	
	return($allele2) if($allele2 eq "A" || $allele2 eq "C" || $allele2 eq "G" || $allele2 eq "T");
	
	if($allele2 eq "M")
	{
		return("C") if($allele1 eq "A");
		return("A") if($allele1 eq "C");
	}
	elsif($allele2 eq "R")
	{
		return("G") if($allele1 eq "A");
		return("A") if($allele1 eq "G");		
	}
	elsif($allele2 eq "W")
	{
		return("T") if($allele1 eq "A");
		return("A") if($allele1 eq "T");		
	}
	elsif($allele2 eq "S")
	{
		return("C") if($allele1 eq "G");
		return("G") if($allele1 eq "C");		
	}
	elsif($allele2 eq "Y")
	{
		return("C") if($allele1 eq "T");
		return("T") if($allele1 eq "C");		
	}
	elsif($allele2 eq "K")
	{
		return("G") if($allele1 eq "T");
		return("T") if($allele1 eq "G");				
	}	
	
	return($allele2);
}


#############################################################
# ParseBlocks - takes input file and parses it
#
#############################################################

sub iupac_to_genotype
{
	(my $allele1, my $allele2) = @_;
	
	return($allele2 . $allele2) if($allele2 eq "A" || $allele2 eq "C" || $allele2 eq "G" || $allele2 eq "T");
	
	if($allele2 eq "M")
	{
		return("AC") if($allele1 eq "A");
		return("CA") if($allele1 eq "C");
	}
	elsif($allele2 eq "R")
	{
		return("AG") if($allele1 eq "A");
		return("GA") if($allele1 eq "G");		
	}
	elsif($allele2 eq "W")
	{
		return("AT") if($allele1 eq "A");
		return("TA") if($allele1 eq "T");		
	}
	elsif($allele2 eq "S")
	{
		return("GC") if($allele1 eq "G");
		return("CG") if($allele1 eq "C");		
	}
	elsif($allele2 eq "Y")
	{
		return("TC") if($allele1 eq "T");
		return("CT") if($allele1 eq "C");		
	}
	elsif($allele2 eq "K")
	{
		return("TG") if($allele1 eq "T");
		return("GT") if($allele1 eq "G");				
	}	
	
	return($allele2);
}




#############################################################
# ParseBlocks - takes input file and parses it
#
#############################################################

sub trv_to_mutation_type
{
	my $trv_type = shift(@_);
	
	return("Missense_Mutation") if($trv_type eq "missense");	
	return("Nonsense_Mutation") if($trv_type eq "nonsense");	
	return("Silent_Mutation") if($trv_type eq "silent");		
	return("Splice_Site_Mutation") if($trv_type eq "splice_site");		
	return("Unknown");
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub byChrPos
{
	my ($chrom_a, $pos_a) = split(/\t/, $a);
	my ($chrom_b, $pos_b) = split(/\t/, $b);
	
	$chrom_a =~ s/X/23/;
	$chrom_a =~ s/Y/24/;
	$chrom_a =~ s/MT/25/;

	$chrom_b =~ s/X/23/;
	$chrom_b =~ s/Y/24/;
	$chrom_b =~ s/MT/25/;

	$chrom_a <=> $chrom_a
	or
	$pos_a <=> $pos_b;
}

1;

