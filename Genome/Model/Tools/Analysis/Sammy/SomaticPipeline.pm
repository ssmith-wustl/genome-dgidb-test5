
package Genome::Model::Tools::Analysis::Sammy::SomaticPipeline;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# SomaticPipeline - Call somatic variants from normal/tumor BAM files
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	07/28/2009 by D.K.
#	MODIFIED:	07/28/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it


## Set Default Parameters ##

my $min_coverage = 8;
my $min_reads2 = 2;
my $min_var_freq = 0.10;
my $min_p_value = 1.0E-06;
my %dbsnp_variants = ();

class Genome::Model::Tools::Analysis::Sammy::SomaticPipeline {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		output_dir	=> { is => 'Text', doc => "Output directory for somatic calls", is_optional => 0 },
		sample_name	=> { is => 'Text', doc => "Sample name for file naming purposes", is_optional => 0 },
		regions_file	=> { is => 'Text', doc => "Tab-delimited file of target regions", is_optional => 1 },
		normal_bam	=> { is => 'Text', doc => "BAM file for normal sample", is_optional => 1 },
		tumor_bam	=> { is => 'Text', doc => "BAM file for tumor sample" , is_optional => 1},
		normal_pileup	=> { is => 'Text', doc => "Pileup file for normal sample", is_optional => 1 },
		tumor_pileup	=> { is => 'Text', doc => "Pileup file for tumor sample" , is_optional => 1},
		reference	=> { is => 'Text', doc => "Reference file for alignments" , is_optional => 1},
		dbsnp_file	=> { is => 'Text', doc => "Tab-delimited file containing known dbSNPs", is_optional => 1 },
		min_p_value	        => { is => 'Text', doc => "P-value threshold for somatic variants [1.0E-06]", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Calls somatic variants from normal and tumor BAM files"                 
}

sub help_synopsis {
    return <<EOS
This command calls somatic variants from Normal and Tumor alignments files using Dan Koboldt's Sammy package
EXAMPLE:	gt analysis sammy
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
	my $sample_name = $self->sample_name;
	
	## Get reference fasta or use default ##
	
	my $reference_file = $self->reference;
	$reference_file = "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa" if(!$self->reference);

	my $dbsnp_file = $self->dbsnp_file;
	$dbsnp_file = "/gscuser/dkoboldt/SNPseek/SNPseek2/ucsc/snp130.variants.txt" if(!$dbsnp_file);

	## Create output directory ##
	mkdir($self->output_dir) if(!(-d $self->output_dir));

	## Get variables ##
	
	$min_p_value = $self->min_p_value if($self->min_p_value);


	## Declare variables ##

	my $normal_pileup, my $tumor_pileup, my $normal_snp, my $tumor_snp, my $normal_indel, my $tumor_indel;


	## Verify NORMAL Pileup ##

	if($self->normal_pileup)
	{
		$normal_pileup = $self->normal_pileup;
	}
	elsif($self->normal_bam)
	{
		$normal_pileup = $self->output_dir . "/" . $self->sample_name . ".normal.pileup";

		if(!(-e $normal_pileup))
		{
			## Build pileup from BAM ##
			print "Building Pileup for Normal...\n";
			my $cmd = "samtools pileup -f " . $reference_file . " " . $self->normal_bam;
			if($self->regions_file)
			{
				$cmd .= " | " . call_sammy() . "limit-snps --regions-file " . $self->regions_file . " --output-file $normal_pileup";
			}
			else
			{
				$cmd .= " >$normal_pileup";
			}

			system($cmd);
		}
	}
	else
	{
		die "Normal BAM/Pileup file not found!\n";
	}


	## Verify TUMOR Pileup ##

	if($self->tumor_pileup)
	{
		$tumor_pileup = $self->tumor_pileup;
	}
	elsif($self->tumor_bam)
	{
		$tumor_pileup = $self->output_dir . "/" . $self->sample_name . ".tumor.pileup";

		if(!(-e $tumor_pileup))
		{
			## Build pileup from BAM ##
			print "Building Pileup for Tumor...\n";
			my $cmd = "samtools pileup -f " . $reference_file . " " . $self->tumor_bam;

			if($self->regions_file)
			{
				$cmd .= " | " . call_sammy() . "limit-snps --regions-file " . $self->regions_file . " --output-file $tumor_pileup";
			}
			else
			{
				$cmd .= " >$tumor_pileup";
			}

			system($cmd);
		}
	}
	else
	{
		die "Tumor BAM/Pileup file not found!\n";
	}



	## Verify NORMAL SNP ##

	if(-e "$normal_pileup.snp")
	{
		$normal_snp = "$normal_pileup.snp";
	}
	else
	{
		$normal_snp = $self->output_dir . "/" . $self->sample_name . ".normal.snp";
		
		if(!(-e $normal_snp))
		{
			print "Calling SNPs in Normal...\n"; 
			my $cmd = call_sammy() . "pileup2snp " . $normal_pileup . " --min-coverage $min_coverage --min-reads2 $min_reads2 --min-var-freq $min_var_freq --p-value $min_p_value >$normal_snp";
			system($cmd);
		}
	}


	## Verify Tumor SNP ##

	if(-e "$tumor_pileup.snp")
	{
		$tumor_snp = "$tumor_pileup.snp";
	}
	else
	{
		$tumor_snp = $self->output_dir . "/" . $self->sample_name . ".tumor.snp";
		
		if(!(-e $tumor_snp))
		{
			print "Calling SNPs in Tumor...\n"; 
			my $cmd = call_sammy() . "pileup2snp " . $tumor_pileup . " --min-coverage $min_coverage --min-reads2 $min_reads2 --min-var-freq $min_var_freq --p-value $min_p_value >$tumor_snp";
			system($cmd);
		}
	}


	## Compare SNPs between normal and tumor ##
	
	my $compared_snps = $self->output_dir . "/" . $self->sample_name . ".snps.compared";

	if(-e $normal_snp && -e $tumor_snp)
	{
		if(!(-e $compared_snps))
		{
			## Compare the SNPs ##
			
			my $cmd = call_sammy() . "compare " . $normal_snp . " " . $tumor_snp . " " . $compared_snps;
	
			print "Comparing SNPs between Normal and Tumor...\n";
			system($cmd);
		}
	}
	else
	{
		die "Missing Normal or Tumor SNP file ($normal_snp or $tumor_snp)\n";
	}

#	my $compared_snps_status = $self->output_dir . "/" . $self->sample_name . ".snps.compared.status";
	my $compared_snps_status = $self->output_dir . "/" . $self->sample_name . ".snps.compared.status.filtered";	

	if(!(-e $compared_snps_status))
	{
		print "Calling variants as Germline or Somatic...\n";
		my $cmd = call_sammy() . "somatic " . $normal_pileup . " " . $tumor_pileup . " " . $compared_snps . " " . $compared_snps_status;		
		system($cmd);
	}


	## Load dbsnps ##
	
	%dbsnp_variants = load_dbsnp($dbsnp_file);


	## Proceed with comparison ##
	
	if(-e $compared_snps_status)
	{
		## SOMATIC ##
		
		my $somatic_file = $self->output_dir . "/" . $self->sample_name . ".snps.somatic";
		
		(my $num_somatic, my $num_somatic_dbSNP) = parse_variants_by_status($compared_snps_status, "Somatic", $somatic_file);
		print "$num_somatic Somatic variants ($num_somatic_dbSNP dbSNP)\n";

		if($num_somatic)
		{
			run_annotation($somatic_file);
		}

		
		## LOH ##

		my $loh_file = $self->output_dir . "/" . $self->sample_name . ".snps.loh";

		(my $num_loh, my $num_loh_dbSNP) = parse_variants_by_status($compared_snps_status, "LOH", $loh_file);
		print "$num_loh LOH variants ($num_loh_dbSNP dbSNP)\n";

		if($num_loh)
		{
			run_annotation($loh_file);
		}
		
		## GERMLINE ##

		my $germline_file = $self->output_dir . "/" . $self->sample_name . ".snps.germline";
		(my $num_germline, my $num_germline_dbSNP) = parse_variants_by_status($compared_snps_status, "Germline", $germline_file);
		print "$num_germline Germline variants ($num_germline_dbSNP dbSNP)\n";

	}
	else
	{
		die "No file of compared SNPs ($compared_snps) was generated!\n";
	}
}





#####################################################################################
# parse_variants_by_status
#
#####################################################################################

sub parse_variants_by_status
{
	(my $infile, my $desired_status, my $outfile) = @_;

	my $num_matching = 0;
	my $num_dbSNP = 0;

	if(-e $infile)
	{
		open(OUTFILE, ">$outfile") or die "Can't open outfile: $!\n";
	
		my $input = new FileHandle ($infile);
		my $lineCounter = 0;
		
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;		
	
			if($line)
			{
				my @lineContents = split(/\t/, $line);
				my $chrom = $lineContents[0];
				$chrom =~ s/[^0-9XYMT]//g;
				my $position = $lineContents[1];
				my $allele1 = $lineContents[2];
				my $allele2 = $lineContents[3];
				my $status = $lineContents[12];
				my $p_value = $lineContents[13];
	
				if($status && $status eq $desired_status && $p_value <= $min_p_value)
				{
					my $key = "$chrom\t$position";
					
					if($dbsnp_variants{$key})
					{
						$line .= "\t" . $dbsnp_variants{$key};
						$num_dbSNP++;
					}					
					
					print OUTFILE "$line\n";
					$num_matching++;
					
				}
	
			}		
		}
	
		
		close($input);
		
		close(OUTFILE);

	}
	
	return($num_matching, $num_dbSNP);
}




#####################################################################################
# run_annotation
#
#####################################################################################

sub run_annotation
{
	(my $variants_file) = @_;
	
	my $formatted_file = $variants_file . ".formatted";
	my $annotated_file = $variants_file . ".formatted.annotations";
	my $merged_file = $variants_file . ".annotated";


	print "Annotating variants in $variants_file...\n";	

	## Format SNPs for annotation ##

	system("perl ~dkoboldt/src/mptrunk/trunk/Auto454/format_snps_for_annotation.pl $variants_file $formatted_file");			

	if(!(-e $annotated_file))
	{
		system("gt annotate transcript-variants --variant-file $formatted_file --output-file $annotated_file 1>/dev/null 2>/dev/null");
	}
	
	print "Merging annotations with SNP calls...\n";

	system("perl ~dkoboldt/src/mptrunk/trunk/Auto454/format_snps_with_annotation.pl $variants_file $annotated_file $merged_file");
}




#####################################################################################
# load_dbsnp 
#
#####################################################################################

sub load_dbsnp
{
	(my $infile) = @_;

	my %snps = ();

	if(-e $infile)
	{
		my $input = new FileHandle ($infile);
		my $lineCounter = 0;
		
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;		
	
			if($line)
			{
				my @lineContents = split(/\t/, $line);
				my $chrom = $lineContents[0];
				$chrom =~ s/[^0-9XYMT]//g;
				my $position = $lineContents[1];
				my $rs_number = $lineContents[2];
	
				my $key = "$chrom\t$position";
				$snps{$key} = $rs_number;
			}		
		}
	
		
		close($input);
		
		close(OUTFILE);

	}
	
	return(%snps);
}



#####################################################################################
# call_sammy - Call Sammy3
#
#####################################################################################

sub call_sammy
{
	my $classpath = "/gscuser/dkoboldt/Software/Sammy3";
	my $cmd = "java -Xms3000m -Xmx3000m -classpath $classpath Sammy ";
	return($cmd);
}



sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}

1;

