
package Genome::Model::Tools::Analysis::LaneQc::CompareSnps;     # rename this when you give the module file a different name <--

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

class Genome::Model::Tools::Analysis::LaneQc::CompareSnps {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		genotype_file	=> { is => 'Text', doc => "Three-column file of genotype calls chrom, pos, genotype", is_optional => 0, is_input => 1 },
		variant_file	=> { is => 'Text', doc => "Variant calls in SAMtools pileup-consensus format", is_optional => 0, is_input => 1 },
		min_depth	=> { is => 'Text', doc => "Minimum depth to include a variant call [4]", is_optional => 1, is_input => 1},
		verbose	=> { is => 'Text', doc => "Turns on verbose output [0]", is_optional => 1, is_input => 1}
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Compares SAMtools variant calls to array genotypes"                 
}

sub help_synopsis {
    return <<EOS
This command searches for Illumina/Solexa data using the database
EXAMPLE:	gmt analysis lane-qc compare-snps --genotype-file affy.genotypes --variant-file lane1.var
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
	my $genotype_file = $self->genotype_file;
	my $variant_file = $self->variant_file;
	my $min_depth = 4;
	$min_depth = $self->min_depth if($self->min_depth);
	
	my %stats = ();
	$stats{'num_snps'} = $stats{'num_min_depth'} = $stats{'num_with_genotype'} = $stats{'num_with_variant'} = $stats{'num_variant_match'} = 0;
	$stats{'het_was_hom'} = $stats{'hom_was_het'} = $stats{'het_was_diff_het'} = $stats{'rare_hom_match'} = $stats{'rare_hom_total'} = 0;

	print "Loading genotypes from $genotype_file...\n";
	my %genotypes = load_genotypes($genotype_file);

	print "Parsing variant calls in $variant_file...\n";

	my $input = new FileHandle ($variant_file);
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

			## Get depth ##
			
			if($file_type eq "varscan")
			{
				$depth = $lineContents[4] + $lineContents[5];
			}
			else
			{
				$depth = $lineContents[7];			
			}
	
			## Only check SNP calls ##
	
			if($ref_base ne $cns_call && $ref_base ne "*" && length($ref_base) == 1 && length($cns_call) == 1)
			{
				$stats{'num_snps'}++;
	
				if($depth >= $min_depth)
				{
					$stats{'num_min_depth'}++;
					
					my $key = "$chrom\t$position";
					
					if($genotypes{$key})
					{
						$stats{'num_with_genotype'}++;
						
						my $chip_gt = sort_genotype($genotypes{$key});
						my $ref_gt = code_to_genotype($ref_base);
						my $cons_gt = code_to_genotype($cns_call);
	
						if($chip_gt eq $ref_gt)
						{
							$stats{'num_chip_was_reference'}++;
							
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
							
							if($self->verbose)
							{
								print "$line\t$chip_gt $comparison_result $cons_gt\n";
							}
							
							
						}
						
					}
				}
			}			
		}
		

		
	}
	
	close($input);

	## Calculate pct ##
	
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

	
	print $stats{'num_snps'} . " SNPs parsed from variants file\n";
	print $stats{'num_min_depth'} . " met minimum depth of >= $min_depth\n";
	print $stats{'num_with_genotype'} . " had genotype calls from the SNP array\n";
	print $stats{'num_with_variant'} . " had informative genotype calls\n";
	print $stats{'num_variant_match'} . " had matching calls from sequencing\n";
	print $stats{'hom_was_het'} . " homozygotes from array were called heterozygous\n";
	print $stats{'het_was_hom'} . " heterozygotes from array were called homozygous\n";
	print $stats{'het_was_diff_het'} . " heterozygotes from array were different heterozygote\n";

	print $stats{'pct_variant_match'} . "% concordance at variant sites\n";
	print $stats{'pct_hom_match'} . "% concordance at rare-homozygous sites\n";

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


################################################################################################
# Load Genotypes
#
################################################################################################

sub load_genotypes
{                               # replace with real execution logic.
	my $genotype_file = shift(@_);
	my %genotypes = ();
	
	my $input = new FileHandle ($genotype_file);
	my $lineCounter = 0;
	my $gtCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		(my $chrom, my $position, my $genotype) = split(/\t/, $line);

		my $key = "$chrom\t$position";
		
		if($genotype && $genotype ne "--")
		{
			$genotypes{$key} = $genotype;
			$gtCounter++;
		}
	}
	close($input);

	print "$gtCounter genotypes loaded\n";
	
	return(%genotypes);                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
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

	warn "Unrecognized ambiguity code $code!\n";

	return("NN");	
}



sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;

