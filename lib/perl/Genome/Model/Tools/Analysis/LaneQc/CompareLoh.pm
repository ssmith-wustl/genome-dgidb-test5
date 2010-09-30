
package Genome::Model::Tools::Analysis::LaneQc::CompareLoh;     # rename this when you give the module file a different name <--

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

class Genome::Model::Tools::Analysis::LaneQc::CompareLoh {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		loh_file	=> { is => 'Text', doc => "Three-column file of genotype calls chrom, pos, genotype", is_optional => 0, is_input => 1 },
		variant_file	=> { is => 'Text', doc => "Variant calls in SAMtools pileup-consensus format", is_optional => 1, is_input => 1 },
		bam_file	=> { is => 'Text', doc => "Alternatively, provide a BAM file", is_optional => 1, is_input => 1 },		
		sample_name	=> { is => 'Text', doc => "Variant calls in SAMtools pileup-consensus format", is_optional => 1, is_input => 1 },
		min_depth_het	=> { is => 'Text', doc => "Minimum depth to compare a het call [4]", is_optional => 1, is_input => 1},
		min_depth_hom	=> { is => 'Text', doc => "Minimum depth to compare a hom call [8]", is_optional => 1, is_input => 1},
		verbose	=> { is => 'Text', doc => "Turns on verbose output [0]", is_optional => 1, is_input => 1},
		flip_alleles 	=> { is => 'Text', doc => "If set to 1, try to avoid strand issues by flipping alleles to match", is_optional => 1, is_input => 1},
		output_file	=> { is => 'Text', doc => "Output file for QC result", is_optional => 1, is_input => 1}
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Compares SAMtools variant calls to array genotypes"                 
}

sub help_synopsis {
    return <<EOS
This command compares SAMtools variant calls to array genotypes
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
	my $sample_name = "Sample";

	if($self->sample_name)
	{
		$sample_name = $self->sample_name;
	}
	elsif($self->variant_file)
	{
		$sample_name = $self->variant_file if($self->variant_file);	
	}
	elsif($self->bam_file)
	{
		$sample_name = $self->bam_file if($self->bam_file);	
	}
	
	my $loh_file = $self->loh_file;

	my $variant_file = "";

	print "Loading LOH calls from $loh_file...\n" if($self->verbose);
	my %genotypes = load_genotypes($loh_file);

	
	if($self->bam_file)
	{
		my $bam_file = $self->bam_file;

		## Build positions key ##
		my $search_string = "";
		my $key_count = 0;
		foreach my $key (sort byBamOrder keys %genotypes)
		{
			$key_count++;
			(my $chrom, my $position) = split(/\t/, $key);
			$search_string .= " " if($search_string);
			
			$search_string .= $chrom . ":" . $position . "-" . $position;
		}
		
		## If BAM provided, call the variants ##
		    my ($tfh,$temp_path) = Genome::Utility::FileSystem->create_temp_file;
		    unless($tfh) {
		        $self->error_message("Unable to create temporary file $!");
		        die;
			}

		## Build consensus ##
		print "Building pileup to $temp_path\n";
		my $cmd = "";
		
		if($search_string && $key_count < 100)
		{
			print "Extracting genotypes for $key_count positions...\n";		
			$cmd = "samtools view -b $bam_file $search_string | samtools pileup -f /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa - | java -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan pileup2cns >$temp_path";			
			print "$cmd\n";
		}
		else
		{
			$cmd = "samtools pileup -cf /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa $bam_file | cut --fields=1-8 >$temp_path";			
		}

		system($cmd);
		
		$variant_file = $temp_path;
	}
	elsif($self->variant_file)
	{
		$variant_file = $self->variant_file;
	}
	else
	{
		die "Please provide a variant file or a BAM file\n";
	}

	$sample_name = $self->sample_name if($self->sample_name);
	my $min_depth_hom = 4;
	my $min_depth_het = 8;
	$min_depth_hom = $self->min_depth_hom if($self->min_depth_hom);
	$min_depth_het = $self->min_depth_het if($self->min_depth_het);
	
	if($self->output_file)
	{
		open(OUTFILE, ">" . $self->output_file) or die "Can't open outfile: $!\n";
#		print OUTFILE "file\tnum_snps\tnum_with_genotype\tnum_min_depth\tnum_variant\tvariant_match\thom_was_het\thet_was_hom\thet_was_diff\tconc_variant\tconc_rare_hom\n";
		#num_ref\tref_was_ref\tref_was_het\tref_was_hom\tconc_overall
	}

	
	my %stats = ();
	$stats{'num_snps'} = $stats{'num_min_depth'} = $stats{'num_with_genotype'} = $stats{'num_with_variant'} = $stats{'num_variant_match'} = 0;
	$stats{'het_was_hom'} = $stats{'hom_was_het'} = $stats{'het_was_diff_het'} = $stats{'rare_hom_match'} = $stats{'rare_hom_total'} = 0;
	$stats{'num_ref_was_ref'} = $stats{'num_ref_was_hom'} = $stats{'num_ref_was_het'} = 0;


	print "Parsing variant calls in $variant_file...\n" if($self->verbose);

	my $input = new FileHandle ($variant_file);
	my $lineCounter = 0;

	my $file_type = "samtools";
	my $verbose_output = "";

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
					## VarScan CNS format ##
					$depth = $lineContents[4] + $lineContents[5];
					$cons_gt = code_to_genotype($cns_call);			
				}
				elsif($file_type eq "varscan")
				{
					## VarScan SNP format ##
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
				
#				warn "$stats{'num_snps'} lines parsed...\n" if(!($stats{'num_snps'} % 10000));
	
				my $key = "$chrom\t$position";
					
				if($genotypes{$key})
				{
					$stats{'num_with_genotype'}++;
					
					if($depth >= $min_depth_het)
					{
						$stats{'num_min_depth'}++;
					
						my $match_status = "";
						
						(my $normal_genotype, my $tumor_genotype) = split(/\t/, $genotypes{$key});
						
						my $normal_gt = sort_genotype($normal_genotype);
						my $tumor_gt = sort_genotype($tumor_genotype);
						my $ref_gt = code_to_genotype($ref_base);
						
						if($cons_gt eq $normal_gt)
						{
							$stats{'num_matched_normal'}++;
							$match_status .= "MatchNormal";
						}

						if($cons_gt eq $tumor_gt)
						{
							$stats{'num_matched_tumor'}++;
							$match_status .= "MatchTumor";
						}

						$match_status = "MatchNeither" if(!$match_status);
					
						if($self->verbose)
						{
							print join("\t", $key, $normal_gt, $tumor_gt, $cons_gt, $match_status) . "\n";
						}						
						
					}
				}
			
			}

		}
		

		
	}
	
	close($input);

	
	## Set zero values ##
	
	$stats{'num_matched_normal'} = 0 if(!$stats{'num_matched_normal'});
	$stats{'num_matched_tumor'} = 0 if(!$stats{'num_matched_tumor'});

	## Calculate pct ##
	
	$stats{'pct_normal_match'} = $stats{'pct_tumor_match'} = "0.00";

	if($stats{'num_min_depth'})
	{
		$stats{'pct_normal_match'} = $stats{'num_matched_normal'} / $stats{'num_min_depth'} * 100;
		$stats{'pct_normal_match'} = sprintf("%.3f", $stats{'pct_normal_match'});

		$stats{'pct_tumor_match'} = $stats{'num_matched_tumor'} / $stats{'num_min_depth'} * 100;
		$stats{'pct_tumor_match'} = sprintf("%.3f", $stats{'pct_tumor_match'});

	}
	else
	{
		$stats{'pct_normal_match'} = $stats{'pct_tumor_match'} = "--";
	}

	print join("\t", $stats{'num_min_depth'}, $stats{'num_matched_normal'}, $stats{'pct_normal_match'} . '%', $stats{'num_matched_tumor'}, $stats{'pct_tumor_match'} . '%') . "\n";

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


################################################################################################
# Load Genotypes
#
################################################################################################

sub load_genotypes
{                               # replace with real execution logic.
	my $loh_file = shift(@_);
	my %genotypes = ();
	
	my $input = new FileHandle ($loh_file);
	my $lineCounter = 0;
	my $gtCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		(my $chrom, my $position, my $normal_genotype, my $tumor_genotype) = split(/\t/, $line);

		my $key = "$chrom\t$position";
		
		$genotypes{$key} = "$normal_genotype\t$tumor_genotype";
		$gtCounter++;
	}
	close($input);

#	print "$gtCounter genotypes loaded\n";
	
	return(%genotypes);                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


################################################################################################
# Sorting
#
################################################################################################


sub byBamOrder
{
	my ($chrom_a, $pos_a) = split(/\t/, $a);
	my ($chrom_b, $pos_b) = split(/\t/, $b);
	
	$chrom_a =~ s/X/9\.1/;
	$chrom_a =~ s/Y/9\.2/;
	$chrom_a =~ s/MT/25/;
	$chrom_a =~ s/M/25/;
	$chrom_a =~ s/NT/99/;
	$chrom_a =~ s/[^0-9\.]//g;

	$chrom_b =~ s/X/9\.1/;
	$chrom_b =~ s/Y/9\.2/;
	$chrom_b =~ s/MT/25/;
	$chrom_b =~ s/M/25/;
	$chrom_b =~ s/NT/99/;
	$chrom_b =~ s/[^0-9\.]//g;

	$chrom_a <=> $chrom_b
	or
	$pos_a <=> $pos_b;
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

