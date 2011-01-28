
package Genome::Model::Tools::Analysis::LaneQc::CompareSamples;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# SearchRuns - Search the database for runs
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

my %stats = ();

class Genome::Model::Tools::Analysis::LaneQc::CompareSamples {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		variant_file1	=> { is => 'Text', doc => "Three-column file of genotype calls chrom, pos, genotype", is_optional => 0, is_input => 1 },
		variant_file2	=> { is => 'Text', doc => "Variant calls in SAMtools pileup-consensus format", is_optional => 0, is_input => 1 },
		sample_name	=> { is => 'Text', doc => "Variant calls in SAMtools pileup-consensus format", is_optional => 1, is_input => 1 },
		min_depth_het	=> { is => 'Text', doc => "Minimum depth to compare a het call [8]", is_optional => 1, is_input => 1},
		min_depth_hom	=> { is => 'Text', doc => "Minimum depth to compare a hom call [4]", is_optional => 1, is_input => 1},
		verbose	=> { is => 'Text', doc => "Turns on verbose output [0]", is_optional => 1, is_input => 1},
		output_file	=> { is => 'Text', doc => "Output file for QC result", is_optional => 1, is_input => 1}
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Compares SAMtools variant calls to between two samples"                 
}

sub help_synopsis {
    return <<EOS
This command compares SAMtools variant calls between two samples
EXAMPLE:	gmt analysis lane-qc compare-samples --variant-file1 --variant-file2
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
	my $sample_name = "Sample";

	my $variant_file1 = $self->variant_file1;
	my $variant_file2 = $self->variant_file2;

	$sample_name = $self->sample_name if($self->sample_name);
	my $min_depth_hom = 8;
	my $min_depth_het = 12;
	$min_depth_hom = $self->min_depth_hom if($self->min_depth_hom);
	$min_depth_het = $self->min_depth_het if($self->min_depth_het);
	
	if($self->output_file)
	{
		open(OUTFILE, ">" . $self->output_file) or die "Can't open outfile: $!\n";
	}

	
	$stats{'num_snps'} = $stats{'num_min_depth'} = $stats{'num_with_genotype'} = $stats{'num_with_variant'} = $stats{'num_variant_match'} = 0;
	$stats{'het_was_hom'} = $stats{'hom_was_het'} = $stats{'het_was_diff_het'} = $stats{'rare_hom_match'} = $stats{'rare_hom_total'} = 0;
	$stats{'num_ref_was_ref'} = $stats{'num_ref_was_hom'} = $stats{'num_ref_was_het'} = 0;
	$stats{'num_chip_was_reference'} = 0;
	
	print "Loading variants from file 1...\n";
	my %variant_calls1 = load_variant_calls($variant_file1, $min_depth_het, $min_depth_hom);
	print $stats{'num_snps'} . " SNPs loaded\n";
	$stats{'num_snps'} = 0;
	
	print "Loading variants from file 2...\n";
	my %variant_calls2 = load_variant_calls($variant_file2, $min_depth_het, $min_depth_hom);
	print $stats{'num_snps'} . " SNPs loaded\n";
	$stats{'num_snps'} = 0;

	foreach my $key (keys %variant_calls1)
	{
		if($variant_calls2{$key})
		{
			$stats{'num_snps'}++;			

			my ($ref_base, $chip_gt) = split(/\t/, $variant_calls1{$key});
			($ref_base, my $cons_gt) = split(/\t/, $variant_calls2{$key});
			
			my $ref_gt = code_to_genotype($ref_base);
			
			if($chip_gt eq $ref_gt)
			{
				$stats{'num_chip_was_reference'}++;
			
				if(uc($cons_gt) eq $ref_gt)
				{
					$stats{'num_ref_was_ref'}++;
				}
				elsif(is_heterozygous($cons_gt))
				{
					$stats{'num_ref_was_het'}++;
				}
				else
				{
					$stats{'num_ref_was_hom'}++;
				}
			}
			elsif($chip_gt ne $ref_gt)
			{
				$stats{'num_with_variant'}++;
				
				my $comparison_result = "Unknown";
				
				if(is_homozygous($chip_gt))
				{
					$stats{'rare_hom_total'}++;
				}
			
				if($chip_gt eq $cons_gt)
				{
					$stats{'num_variant_match'}++;
					if(is_homozygous($chip_gt))
					{
						$stats{'rare_hom_match'}++;
					}
					
					$comparison_result = "Match";

				}
				elsif(is_homozygous($chip_gt) && is_heterozygous($cons_gt))
				{
					$stats{'hom_was_het'}++;
					$comparison_result = "HomWasHet";
				}
				elsif(is_heterozygous($chip_gt) && is_homozygous($cons_gt))
				{
					$stats{'het_was_hom'}++;
					$comparison_result = "HetWasHom";
				}
				elsif(is_heterozygous($chip_gt) && is_heterozygous($chip_gt))
				{
					$stats{'het_was_diff_het'}++;
					$comparison_result = "HetMismatch";
				}
				
				
				
			}
		}

	}

	print $stats{'num_snps'} . " SNPs called in both samples\n";

	## Calculate pct ##
	
	$stats{'pct_overall_match'} = "0.00";
	if($stats{'num_with_variant'} || $stats{'num_chip_was_reference'})
	{
		$stats{'pct_overall_match'} = ($stats{'num_variant_match'} + $stats{'num_ref_was_ref'}) / ($stats{'num_chip_was_reference'} + $stats{'num_with_variant'}) * 100;
		$stats{'pct_overall_match'} = sprintf("%.3f", $stats{'pct_overall_match'});
	}

	$stats{'pct_variant_match'} = "0.00";
	if($stats{'num_with_variant'})
	{
		$stats{'pct_variant_match'} = $stats{'num_variant_match'} / $stats{'num_with_variant'} * 100;
		$stats{'pct_variant_match'} = sprintf("%.3f", $stats{'pct_variant_match'});
	}

	$stats{'pct_hom_match'} = "0.00";
	if($stats{'rare_hom_total'})
	{
		$stats{'pct_hom_match'} = $stats{'rare_hom_match'} / $stats{'rare_hom_total'} * 100;
		$stats{'pct_hom_match'} = sprintf("%.3f", $stats{'pct_hom_match'});
	}

	if($self->verbose)
	{
		print $stats{'num_snps'} . " SNPs parsed from variants file\n";
		print $stats{'num_with_genotype'} . " had genotype calls from the SNP array\n";
		print $stats{'num_min_depth'} . " met minimum depth of >= $min_depth_hom/$min_depth_het\n";
		print $stats{'num_chip_was_reference'} . " were called Reference on chip\n";
		print $stats{'num_ref_was_ref'} . " reference were called reference\n";
		print $stats{'num_ref_was_het'} . " reference were called heterozygous\n";
		print $stats{'num_ref_was_hom'} . " reference were called homozygous\n";
		print $stats{'num_with_variant'} . " had informative genotype calls\n";
		print $stats{'num_variant_match'} . " had matching calls from sequencing\n";
		print $stats{'hom_was_het'} . " homozygotes from array were called heterozygous\n";
		print $stats{'het_was_hom'} . " heterozygotes from array were called homozygous\n";
		print $stats{'het_was_diff_het'} . " heterozygotes from array were different heterozygote\n";
		print $stats{'pct_variant_match'} . "% concordance at variant sites\n";
		print $stats{'pct_hom_match'} . "% concordance at rare-homozygous sites\n";
		print $stats{'pct_overall_match'} . "% overall concordance match\n";
	}
	else
	{
		print "Sample\tSNPsCalled\tWithGenotype\tMetMinDepth\tReference\tRefMatch\tRefWasHet\tRefWasHom\tVariant\tVarMatch\tHomWasHet\tHetWasHom\tVarMismatch\tVarConcord\tRareHomConcord\tOverallConcord\n";
		print "$sample_name\t";
		print $stats{'num_snps'} . "\t";
		print $stats{'num_with_genotype'} . "\t";
		print $stats{'num_min_depth'} . "\t";
		print $stats{'num_chip_was_reference'} . "\t";
		print $stats{'num_ref_was_ref'} . "\t";
		print $stats{'num_ref_was_het'} . "\t";
		print $stats{'num_ref_was_hom'} . "\t";
		print $stats{'num_with_variant'} . "\t";
		print $stats{'num_variant_match'} . "\t";
		print $stats{'hom_was_het'} . "\t";
		print $stats{'het_was_hom'} . "\t";
		print $stats{'het_was_diff_het'} . "\t";
		print $stats{'pct_variant_match'} . "%\t";
		print $stats{'pct_hom_match'} . "%\t";		
		print $stats{'pct_overall_match'} . "%\n";
	}

	if($self->output_file)
	{
		print OUTFILE "Sample\tSNPsCalled\tWithGenotype\tMetMinDepth\tReference\tRefMatch\tRefWasHet\tRefWasHom\tVariant\tVarMatch\tHomWasHet\tHetWasHom\tVarMismatch\tVarConcord\tRareHomConcord\tOverallConcord\n";
		print OUTFILE "$sample_name\t";
		print OUTFILE $stats{'num_snps'} . "\t";
		print OUTFILE $stats{'num_with_genotype'} . "\t";
		print OUTFILE $stats{'num_min_depth'} . "\t";
		print OUTFILE $stats{'num_chip_was_reference'} . "\t";
		print OUTFILE $stats{'num_ref_was_ref'} . "\t";
		print OUTFILE $stats{'num_ref_was_het'} . "\t";
		print OUTFILE $stats{'num_ref_was_hom'} . "\t";
		print OUTFILE $stats{'num_with_variant'} . "\t";
		print OUTFILE $stats{'num_variant_match'} . "\t";
		print OUTFILE $stats{'hom_was_het'} . "\t";
		print OUTFILE $stats{'het_was_hom'} . "\t";
		print OUTFILE $stats{'het_was_diff_het'} . "\t";
		print OUTFILE $stats{'pct_variant_match'} . "%\t";
		print OUTFILE $stats{'pct_hom_match'} . "%\t";		
		print OUTFILE $stats{'pct_overall_match'} . "%\n";		
	}

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


################################################################################################
# Load Genotypes
#
################################################################################################

sub load_variant_calls
{
	my ($FileName, $min_depth_het, $min_depth_hom) = @_;

	my %calls = ();
	
	# replace with real execution logic.
	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;

	my $file_type = "samtools";

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		my @lineContents = split(/\t/, $line);
		my $chrom = $lineContents[0];
		my $position = $lineContents[1];
		my $ref_base = $lineContents[2];
		my $cns_call = $lineContents[3];
		
		my $depth = 0;
		
		if(lc($chrom) =~ "chrom")
		{
			## Ignore header ##
			$file_type = "varscan";
		}
		else
		{
			if($lineContents[6] && $lineContents[6] =~ '%')
			{
				$file_type = "varscan";
			}

			## Only check SNP calls ##
	
			if($ref_base ne "*" && length($ref_base) == 1 && length($cns_call) == 1) #$ref_base ne $cns_call
			{
				## Get depth and consensus genotype ##
	
				my $cons_gt = "";			
	
				if($file_type eq "varscan" && $cns_call ne "A" && $cns_call ne "C" && $cns_call ne "G" && $cns_call ne "T")
				{
					## Varscan CNS format ##
					$depth = $lineContents[4] + $lineContents[5];
					$cons_gt = code_to_genotype($cns_call);			
				}
				elsif($file_type eq "varscan")
				{
					## Varscan SNP format ##
					$depth = $lineContents[4] + $lineContents[5];
					my $var_freq = $lineContents[6];
					my $allele1 = $lineContents[2];
					my $allele2 = $lineContents[3];
					$var_freq =~ s/\%//;
					if($var_freq >= 80)
					{
						$cons_gt = $allele2 . $allele2;
					}
					else
					{
						$cons_gt = $allele1 . $allele2;
						$cons_gt = sort_genotype($cons_gt);
					}					
				}
				
				else
				{
					$depth = $lineContents[7];
					$cons_gt = code_to_genotype($cns_call);
				}
	
				$stats{'num_snps'}++;

				if($depth >= $min_depth_het)
				{
					my $snp_key = join("\t", $chrom, $position);
					$calls{$snp_key} = "$ref_base\t$cons_gt";								
				}

			}

		}
		

		
	}
	
	close($input);


	return(%calls);
                     # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



################################################################################################
# Load Genotypes
#
################################################################################################

sub is_heterozygous
{
	my $gt = shift(@_);
	(my $a1, my $a2) = split(//, $gt);
	return(1) if($a1 ne $a2);
	return(0);
}



################################################################################################
# Load Genotypes
#
################################################################################################

sub is_homozygous
{
	my $gt = shift(@_);
	(my $a1, my $a2) = split(//, $gt);
	return(1) if($a1 eq $a2);
	return(0);
}



################################################################################################
# Load Genotypes
#
################################################################################################

sub flip_genotype
{
	my $gt = shift(@_);
	(my $a1, my $a2) = split(//, $gt);

	if($a1 eq "A")
	{
		$a1 = "T";
	}
	elsif($a1 eq "C")
	{
		$a1 = "G";
	}
	elsif($a1 eq "G")
	{
		$a1 = "C";
	}	
	elsif($a1 eq "T")
	{
		$a1 = "A";		
	}

	if($a2 eq "A")
	{
		$a2 = "T";
	}
	elsif($a2 eq "C")
	{
		$a2 = "G";
	}
	elsif($a2 eq "G")
	{
		$a2 = "C";
	}	
	elsif($a2 eq "T")
	{
		$a2 = "A";		
	}
	
	$gt = $a1 . $a2;
	$gt = sort_genotype($gt);
	return($gt);
}

################################################################################################
# Load Genotypes
#
################################################################################################

sub sort_genotype
{
	my $gt = shift(@_);
	(my $a1, my $a2) = split(//, $gt);

	my @unsorted = ($a1, $a2);
	my @sorted = sort @unsorted;
	$a1 = $sorted[0];
	$a2 = $sorted[1];
	return($a1 . $a2);
}



sub code_to_genotype
{
	my $code = shift(@_);
	
	return("AA") if($code eq "A");
	return("CC") if($code eq "C");
	return("GG") if($code eq "G");
	return("TT") if($code eq "T");

	return("AC") if($code eq "M");
	return("AG") if($code eq "R");
	return("AT") if($code eq "W");
	return("CG") if($code eq "S");
	return("CT") if($code eq "Y");
	return("GT") if($code eq "K");

#	warn "Unrecognized ambiguity code $code!\n";

	return("NN");	
}



sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;

