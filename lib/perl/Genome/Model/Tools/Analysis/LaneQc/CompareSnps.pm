
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
		variant_file	=> { is => 'Text', doc => "Variant calls in SAMtools pileup-consensus format", is_optional => 1, is_input => 1 },
		bam_file	=> { is => 'Text', doc => "Alternatively, provide a BAM file", is_optional => 1, is_input => 1 },		
		sample_name	=> { is => 'Text', doc => "Variant calls in SAMtools pileup-consensus format", is_optional => 1, is_input => 1 },
		min_depth_het	=> { is => 'Text', doc => "Minimum depth to compare a het call", is_optional => 1, is_input => 1, default => 8},
		min_depth_hom	=> { is => 'Text', doc => "Minimum depth to compare a hom call", is_optional => 1, is_input => 1, default => 4},
		reference_build	=> { is => 'Text', doc => "36 or 37", is_optional => 1, is_input => 1, default => 36},
		verbose	=> { is => 'Text', doc => "Turns on verbose output [0]", is_optional => 1, is_input => 1},
		flip_alleles 	=> { is => 'Text', doc => "If set to 1, try to avoid strand issues by flipping alleles to match", is_optional => 1, is_input => 1},
		fast 	=> { is => 'Text', doc => "If set to 1, run a quick check on just chromosome 1", is_optional => 1, is_input => 1},
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

sub output_columns {
    return qw/
          Sample
          SnpsCalled
          WithGenotype
          MetMinDepth
          Reference
          RefMatch
          RefWasHet
          RefWasHom
          Variant
          VarMatch
          HomWasHet
          HetWasHom
          VarMismatch
          VarConcord
          RareHomConcord
          OverallConcord
    /;
}

################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;
    $DB::single=1;
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
	
	my $genotype_file = $self->genotype_file;

	my $variant_file = "";


	print "Loading genotypes from $genotype_file...\n" if($self->verbose);
	my %genotypes = load_genotypes($genotype_file, $self);


	my $reference_build = $self->reference_build;
	my $reference_build_fasta;
	if ($reference_build =~ m/36/) {
		$reference_build_fasta = '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa';
	}
	elsif ($reference_build =~ m/37/) {
		$reference_build_fasta = '/gscmnt/sata420/info/model_data/2857786885/build102671028/all_sequences.fa';
	}
	else {
		die "Please specify either build 36 or 37";
	}
	
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
		    my ($tfh,$temp_path) = Genome::Sys->create_temp_file;
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
			$cmd = "samtools view -b $bam_file $search_string | samtools pileup -f $reference_build_fasta - | java -jar /gsc/scripts/lib/java/VarScan/VarScan.jar pileup2cns >$temp_path";			
			print "$cmd\n";
		}
		else
		{
			$cmd = "samtools pileup -cf $reference_build_fasta $bam_file | cut --fields=1-8 >$temp_path";			
		}

		my $return = Genome::Sys->shellcmd(
                           cmd => "$cmd",
                           output_files => [$temp_path],
                           skip_if_output_is_present => 0,
                       );
		unless($return) { 
			$self->error_message("Failed to execute samtools pileup: Pileup Returned $return");
			die $self->error_message;
		}
		
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
	my $min_depth_hom = $self->min_depth_hom if($self->min_depth_hom);
	my $min_depth_het = $self->min_depth_het if($self->min_depth_het);
	
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
        my ($position, $ref_base, $cns_call, $depth);

		my $chrom = $lineContents[0];
        if($self->variant_file =~ m/bed$/) {
            $position = $lineContents[2];
            ($ref_base, $cns_call)  = split /\//, $lineContents[3];
            $depth = $lineContents[5];
        } else {
            $position = $lineContents[1];
            $ref_base = $lineContents[2];
            $cns_call = $lineContents[3];
			$depth = $lineContents[7];
        }
		
		if($self->fast && $chrom && $chrom ne "1")
		{
			close($input);
		}
		
		
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
					$cons_gt = code_to_genotype($cns_call);
				}
	
				$stats{'num_snps'}++;
				
#				warn "$stats{'num_snps'} lines parsed...\n" if(!($stats{'num_snps'} % 10000));
	
				my $key = "$chrom\t$position";
					
				if($genotypes{$key})
				{
					$stats{'num_with_genotype'}++;
					
					my $chip_gt = sort_genotype($genotypes{$key});

					if((is_homozygous($chip_gt) && $depth >= $min_depth_hom) || (is_heterozygous($chip_gt) && $depth >= $min_depth_het))
					{
						my $ref_gt = code_to_genotype($ref_base);

						$stats{'num_min_depth'}++;
					
						
						if($self->flip_alleles && $chip_gt ne $cons_gt)
						{
							$chip_gt = flip_genotype($chip_gt);
						}
					
						my $comparison_result = "Unknown";
					
						if($chip_gt eq $ref_gt)
						{
							$stats{'num_chip_was_reference'}++;
						
							if(uc($cons_gt) eq $ref_gt)
							{
								$stats{'num_ref_was_ref'}++;
								$comparison_result = "RefMatch";
							}
							elsif(is_heterozygous($cons_gt))
							{
								$stats{'num_ref_was_het'}++;
								$comparison_result = "RefWasHet";
							}
							else
							{
								$stats{'num_ref_was_hom'}++;
								$comparison_result = "RefWasHom";
							}
						
						}
						elsif($chip_gt ne $ref_gt)
						{
							$stats{'num_with_variant'}++;
													
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
								
								$comparison_result = "VarMatch";
	
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
							else
							{
								warn "Uncounted comparison: Chip=$chip_gt but Seq=$cons_gt\n" if($self->verbose);
							}
							

							
							
						}
					
						if($self->verbose)
						{
							$verbose_output .= "$key\t$chip_gt\t$comparison_result\t$cons_gt\t$line\n" if($self->output_file);
							print "$key\t$chip_gt\t$comparison_result\t$cons_gt\t$line\n";
						}						
						
					}
				}
			
			}

		}
		

		
	}
	
	close($input);

	## Parse out info from variant file ##

	my @fileContents = split(/\//, $variant_file);
	my $numContents = @fileContents;
	my $lane_info = $fileContents[$numContents - 2];
	my $machine_info = $fileContents[$numContents - 3];
	my @machineContents = split(/\_/, $machine_info);
	$numContents = @machineContents;
	my $flowcell = $machineContents[$numContents - 1];
	(my $lane) = split(/\_/, $lane_info);

	## Set zero values ##
	
	$stats{'num_ref_was_ref'} = 0 if(!$stats{'num_ref_was_ref'});
	$stats{'num_chip_was_reference'} = 0 if(!$stats{'num_chip_was_reference'});

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
		
		print OUTFILE "\nVERBOSE OUTPUT:\n$verbose_output\n" if($self->verbose);
	}

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


################################################################################################
# Load Genotypes
#
################################################################################################

sub load_genotypes
{                               # replace with real execution logic.
	my $genotype_file = shift(@_);
	my $self = shift(@_);
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
			if(!$self->fast || $chrom eq "1")
			{
				$genotypes{$key} = $genotype;
				$gtCounter++;				
			}
		}
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

