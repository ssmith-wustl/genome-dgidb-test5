
package Genome::Model::Tools::Analysis::Mendelian::ReportVariants;     # rename this when you give the module file a different name <--

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

my %genotypes = ();

class Genome::Model::Tools::Analysis::Mendelian::ReportVariants {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		variant_file	=> { is => 'Text', doc => "List of variants to consider (annotation format)", is_optional => 0, is_input => 1},
		affected_files	=> { is => 'Text', doc => "Consensus files for affected individuals", is_optional => 0, is_input => 1},
		unaffected_files	=> { is => 'Text', doc => "Consensus files for unaffected individuals", is_optional => 1, is_input => 1},
		output_file	=> { is => 'Text', doc => "Output file for QC result", is_optional => 1, is_input => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Reports variants shared by affected individuals in a Mendelian disease pedigree"                 
}

sub help_synopsis {
    return <<EOS
This command reports variants shared by affected individuals in a Mendelian disease pedigree
EXAMPLE:	gmt analysis mendelian report-variants --annotation-file mySNPs.tier1 --affected-files sample1.cns,sample2.cns --output-file variants.report.tsv
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

	my $variant_file = $self->variant_file;

	my $affected_files = $self->affected_files;
	my $unaffected_files = $self->unaffected_files if($self->unaffected_files);	
	
	if($self->output_file)
	{
		open(OUTFILE, ">" . $self->output_file) or die "Can't open outfile: $!\n";		
	}
	
	my $min_affecteds_variant = 2;
	my $max_unaffecteds_variant = 0;


	my %stats = ();
	
	## Build an array of affected individuals' genotypes ##
	
	my @affected_array = ();
	my $num_affected = my $num_unaffected = 0;
	
	my @affected_files = split(/\,/, $affected_files);
	my @unaffected_files = split(/\,/, $unaffected_files) if($unaffected_files);
	
	print "Loading Affected samples...\n";
	
	## Count the files of each type and print the header ##
	my $header = "";
	
	foreach my $affected_file (@affected_files)
	{
		$num_affected++;
		$header .= "\t" if($header);
		$header .= "AFF:" . $affected_file . "\treads1\treads2\tfreq";
		load_consensus($affected_file);
	}

	foreach my $unaffected_file (@unaffected_files)
	{
		$num_unaffected++;
		$header .= "\t" if($header);
		$header .= "UNAFF:" . $unaffected_file . "\treads1\treads2\tfreq";
		load_consensus($unaffected_file);
	}

	print "$num_affected affected samples\n";
	print "$num_unaffected unaffected samples\n";



	## PRint the header ##
	
	print "$header\n";
	if($self->output_file)
	{
		print OUTFILE "variant\tnum_affected\tnum_unaffected\t$header\n";
	}


	## Print the variants ##


	my $input = new FileHandle ($variant_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);

		if($lineCounter >= 0)
		{
			$stats{'num_variants'}++;
						
			my $sample_genotype_string = "";

			## AFFECTED GENOTYPES ##
			
			my $affecteds_variant = my $unaffecteds_variant = 0;
			
			## See how many affecteds carry it ##
			
			foreach my $affected_file (@affected_files)
			{
#				my %genotypes = load_consensus($affected_file);
				my $sample_genotype = "-\t-\t-\t-";

				my $key = "$affected_file\t$chromosome\t$chr_start";
				
				if($genotypes{$key})
				{
					(my $sample_call, my $sample_reads1, my $sample_reads2, my $sample_freq) = split(/\t/, $genotypes{$key});

					if($sample_call ne $ref)
					{
						## We have a variant in this affected, so count it ##
						
						$affecteds_variant++;
					}

					$sample_call = code_to_genotype($sample_call);

					$sample_genotype = "$sample_call\t$sample_reads1\t$sample_reads2\t$sample_freq";
				}
				$sample_genotype_string .= $sample_genotype . "\t";
			}
			


			## Check to see if it occurred in multiple affected samples ##

			if($affecteds_variant >= $min_affecteds_variant)
			{
				## See how many unaffecteds carry it ##
				
				foreach my $unaffected_file (@unaffected_files)
				{
#					my %genotypes = load_consensus($unaffected_file);
					my $sample_genotype = "-\t-\t-\t-";
					
					my $key = "$unaffected_file\t$chromosome\t$chr_start";
					
					if($genotypes{$key})
					{
						(my $sample_call, my $sample_reads1, my $sample_reads2, my $sample_freq) = split(/\t/, $genotypes{$key});
	
						if($sample_call ne $ref)
						{
							## We have a variant in this affected, so count it ##
							
							$unaffecteds_variant++;
						}
	
						$sample_call = code_to_genotype($sample_call);
	
						$sample_genotype = "$sample_call\t$sample_reads1\t$sample_reads2\t$sample_freq";
					}
	
					$sample_genotype_string .= $sample_genotype . "\t";
				}
	

				$stats{'multiple_affecteds'}++;

				## Proceed if we found few enough unaffecteds with the variant ##

				if($unaffecteds_variant <= $max_unaffecteds_variant)
				{
					$stats{'not_in_unaffected'}++;
					print "$chromosome\t$chr_start\t$chr_stop\t$ref\t$var\t";
					print "$affecteds_variant\t$unaffecteds_variant\t";
					print "$sample_genotype_string";
					print "\n";

					if($self->output_file)
					{
						print OUTFILE "$line\t";
						print OUTFILE "$affecteds_variant\t$unaffecteds_variant\t";
						print OUTFILE "$sample_genotype_string";
						print OUTFILE "\n";
					}
				}
			}

		}		
		
	}
	
	close($input);
	
	if($self->output_file)
	{
		close(OUTFILE);
	}
	
	print $stats{'num_variants'} . " variants\n";
	print $stats{'multiple_affecteds'} . " were present in multiple affected individuals\n";
	print $stats{'not_in_unaffected'} . " were NOT present in unaffected individuals\n";
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




################################################################################################
# Load Genotypes
#
################################################################################################

sub load_consensus
{                               # replace with real execution logic.
	my $genotype_file = shift(@_);
#	my %genotypes = ();
	
	my $input = new FileHandle ($genotype_file);
	my $lineCounter = 0;
	my $gtCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		(my $chrom, my $position, my $ref, my $cns, my $reads1, my $reads2, my $var_freq) = split(/\t/, $line);

		if($ref =~ /[0-9]/)
		{
			($chrom, $position, my $stop, $ref, $cns, $reads1, $reads2, $var_freq) = split(/\t/, $line);			
		}

		if(length($ref) > 1 || length($cns) > 1 || $ref eq "-" || $cns eq "-")
		{
			$cns = "$ref/$cns";
		}
#		my $key = "$chrom\t$position";
		my $key = "$genotype_file\t$chrom\t$position";
		$genotypes{$key} = "$cns\t$reads1\t$reads2\t$var_freq";	
	}
	close($input);
                            # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)

#	return(%genotypes);
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
#	return("NN");
	return($code);
}


sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;

