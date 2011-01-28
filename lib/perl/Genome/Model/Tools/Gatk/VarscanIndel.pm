
package Genome::Model::Tools::Gatk::VarscanIndel;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# SomaticIndel - Call the GATK somatic indel detection pipeline
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	15-Jul-2010 by D.K.
#	MODIFIED:	15-Jul-2010 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Gatk::VarscanIndel {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		gatk_file     => { is => 'Text', doc => "Formatted GATK indel file", is_optional => 0, is_input => 1 },
		output_file     => { is => 'Text', doc => "Output file to receive formatted lines", is_optional => 0, is_input => 1, is_output => 1 },
		skip_if_output_present => { is => 'Text', doc => "Skip if output is present", is_optional => 1, is_input => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Runs Varscan-like somatic mutation calling on GATK indels"                 
}

sub help_synopsis {
    return <<EOS
This command runs Varscan-like somatic mutation calling on GATK indels
EXAMPLE:	gmt gatk varscan-indel gatk-indel gatk.indel.formatted --output-file gatk.indel.formatted.varscan
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
	my $gatk_file = $self->gatk_file;
	my $output_file = $self->output_file;

	my $min_reads2 = 2;
	my $min_freq = 10;
	my $min_freq_for_hom = 70;
	my $somatic_p_threshold = 0.01;

	my %stats = ();

	require("/gscuser/dkoboldt/src/perl_modules/trunk/Varscan/Varscan/lib/Varscan/FisherTest.pm");

	open(OUTFILE, ">$output_file") or die "Can't open outfile: $!\n";
	
	## Parse the variants file ##
	
	my $input = new FileHandle ($gatk_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		

		my @lineContents = split(/\t/, $line);
		my $numContents = @lineContents;
		my ($chrom, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $line);
		my $normal_obs = $lineContents[5];
		my $tumor_obs = $lineContents[11];
		
		## Determine indel type and size ##
		
		my $indel_type = my $indel_size = "";
		my $indel_bases = my $indel_allele = "";
		
		if($ref eq "0" || $ref eq "-")
		{
			$indel_type = "INS";
			$indel_bases = $var;
			$indel_size = length($indel_bases);
			$indel_allele = "+" . $indel_bases;
		}
		else
		{
			$indel_type = "DEL";
			$indel_bases = $ref;
			$indel_size = length($indel_bases);
			$indel_allele = "-" . $indel_bases;
		}
		
		my @normalContents = split(/[\:\/]/, $normal_obs);
		my $normal_reads1 = $normalContents[5];
		my $normal_reads2 = $normalContents[3];
		my $normal_freq = sprintf("%.2f", $normal_reads2 / ($normal_reads1 + $normal_reads2) * 100);

		my @tumorContents = split(/[\:\/]/, $tumor_obs);
		my $tumor_reads1 = $tumorContents[5];
		my $tumor_reads2 = $tumorContents[3];
		my $tumor_freq = sprintf("%.2f", $tumor_reads2 / ($tumor_reads1 + $tumor_reads2) * 100);

		my $gatk_call = $lineContents[17];
		
		my $normal_genotype = my $tumor_genotype = "";

		## Call the genotype in normal ##		
		
		if($normal_reads2 >= $min_reads2 && $normal_freq >= $min_freq)
		{
			if($normal_freq >= $min_freq_for_hom)
			{
				$normal_genotype = "$indel_allele/$indel_allele";
			}
			else
			{
				$normal_genotype = "*/$indel_allele";
			}
		}
		else
		{
			$normal_genotype = "*/*";
		}

		## Call the genotype in normal ##		
		
		if($tumor_reads2 >= $min_reads2 && $tumor_freq >= $min_freq)
		{
			if($tumor_freq >= $min_freq_for_hom)
			{
				$tumor_genotype = "$indel_allele/$indel_allele";
			}
			else
			{
				$tumor_genotype = "*/$indel_allele";
			}
		}
		else
		{
			$tumor_genotype = "*/*";
		}
		
		
		
		## Calculate P-value ##
		my $normal_coverage = $normal_reads1 + $normal_reads2;
		my $tumor_coverage = $tumor_reads1 + $tumor_reads2;
		my $variant_p_value = Varscan::FisherTest::calculate_p_value(($normal_coverage + $tumor_coverage), 0, ($normal_reads1 + $tumor_reads1), ($tumor_reads1 + $tumor_reads2));
		if($variant_p_value < 0.001)
		{
			$variant_p_value = sprintf("%.3e", $variant_p_value);			
		}
		else
		{
			$variant_p_value = sprintf("%.5f", $variant_p_value);			
		}

		my $somatic_p_value = Varscan::FisherTest::calculate_p_value($normal_reads1, $normal_reads2, $tumor_reads1, $tumor_reads2);
		if($somatic_p_value < 0.001)
		{
			$somatic_p_value = sprintf("%.3e", $somatic_p_value);			
		}
		else
		{
			$somatic_p_value = sprintf("%.5f", $somatic_p_value);			
		}


		## Determine Somatic Status ##

		my $somatic_status = "";
	
		if($normal_genotype eq "*/*")
		{
			if($tumor_genotype ne "*/*" && $somatic_p_value < $somatic_p_threshold)
			{
				$somatic_status = "Somatic";
			}
			elsif($normal_freq < 5 && $tumor_freq > 15)
			{
				$somatic_status = "Somatic";
			}
			elsif($variant_p_value < $somatic_p_threshold)
			{
				$somatic_status = "Germline";
			}
			elsif($tumor_genotype eq "*/*")
			{
				$somatic_status = "Reference";
			}
			else
			{
				$somatic_status = "Unknown";
			}
			
		}
		elsif($normal_genotype eq "*/$indel_allele")
		{
			if(($tumor_genotype eq "$indel_allele/$indel_allele" || $tumor_genotype eq "*/*") && $somatic_p_value < $somatic_p_threshold)
			{
				$somatic_status = "LOH";
			}
			else
			{
				$somatic_status = "Germline";
			}
		}
		else
		{
			## Normal is homozygous ##
			$somatic_status = "Germline";
		}

		$stats{$gatk_call . " called " . $somatic_status}++;

		my $rest_of_line = "";
		
		for(my $colCounter = 5; $colCounter < $numContents; $colCounter++)
		{
			$rest_of_line .= "\t" if($rest_of_line);
			$rest_of_line .= $lineContents[$colCounter];
		}
		
		print OUTFILE join("\t", $chrom, $chr_start, $chr_stop, $ref, $var, $normal_reads1, $normal_reads2, $normal_freq . '%', $normal_genotype, $tumor_reads1, $tumor_reads2, $tumor_freq . '%', $tumor_genotype, $somatic_status, $variant_p_value, $somatic_p_value, $rest_of_line) . "\n";
	}
	
	close($input);
	
	foreach my $key (sort keys %stats)
	{
		print $stats{$key} . " $key\n";
	}
	
	close(OUTFILE);


}

1;

