
package Genome::Model::Tools::Varscan::ProcessValidation;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# ProcessValidation - Report the results of validation 
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	10/21/2010 by D.K.
#	MODIFIED:	10/21/2010 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Varscan::ProcessValidation {
	is => 'Command',                       
	
	has_input => [                                # specify the command's single-value properties (parameters) <---
		validation_file		=> { is => 'Text', doc => "VarScan output file for validation data", is_optional => 0 },
		filtered_validation_file		=> { is => 'Text', doc => "VarScan calls passing strand-filter in validation BAM (recommended)", is_optional => 0 },
		min_coverage 	=> { is => 'Text', doc => "Minimum coverage to call a site", is_optional => 1 },
		variants_file 	=> { is => 'Text', doc => "File of variants to report on", is_optional => 0 },
		output_file 	=> { is => 'Text', doc => "Output file for validation results", is_optional => 0, is_output => 1 },
		output_plot 	=> { is => 'Text', doc => "Optional plot of variant allele frequencies", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Processes and reports on validation status of a list of variants"                 
}

sub help_synopsis {
    return <<EOS
Processes and reports on validation status of a list of variants
EXAMPLE:	gmt capture process-validation ...
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
	my $validation_file = $self->validation_file;
	my $filtered_validation_file = $self->filtered_validation_file if($self->filtered_validation_file);
	my $variants_file = $self->variants_file;
	my $output_file = $self->output_file;
	my $output_plot = $self->output_plot;
	
	open(OUTFILE, ">$output_file") or die "Can't open outfile: $!\n";
	print OUTFILE "chrom\tchr_start\tchr_stop\tref\tvar\tcalled\tfilter\tstatus\tv_ref\tv_var\tnorm_reads1\tnorm_reads2\tnorm_freq\tnorm_call\ttum_reads1\ttum_reads2\ttum_freq\ttum_call\tsomatic_status\tgermline_p\tsomatic_p\n";

	open(SOMATIC, ">$output_file.SomaticFreqs") or die "Can't open outfile: $!\n";
	open(GERMLINE, ">$output_file.GermlineFreqs") or die "Can't open outfile: $!\n";
	open(REFERENCE, ">$output_file.ReferenceFreqs") or die "Can't open outfile: $!\n";

	my %validation_results = my %filtered_results = ();

	## Reset statistics ##
	
	my %stats = ();

	## Load the validation results ##
	%validation_results = load_validation_results($validation_file);

	## Load the filtered results ##
	%filtered_results = load_validation_results($filtered_validation_file) if($filtered_validation_file);


	## Parse the variant file ##

	my $input = new FileHandle ($variants_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		next unless $line; #skip blank lines
		$lineCounter++;
		
		my ($chrom, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $line);
		
		my $key = join("\t", $chrom, $chr_start);
		$stats{'num_variants'}++;
		
		my $call_status = my $filter_status = my $validation_status = "";
		my $varscan_results = "";
		my $varscan_freqs = "";
		my $normal_coverage = my $tumor_coverage = 0;
		
		if($filtered_results{$key})
		{
			$stats{'with_filtered_results'}++;
			$call_status = "Yes";
			$filter_status = "Pass";
			my @results = split(/\t/, $filtered_results{$key});
			$validation_status = $results[13];
			$varscan_results = join("\t", $results[3], $results[4], $results[5], $results[6], $results[7], $results[8], $results[9], $results[10], $results[11], $results[12], $results[13], $results[14], $results[15]);
			$varscan_freqs = join("\t", $results[7], $results[11]);
			$varscan_freqs =~ s/\%//g;
			$normal_coverage = $results[5] + $results[6];
			$tumor_coverage = $results[9] + $results[10];
		}
		elsif($validation_results{$key})
		{
			$stats{'with_unfiltered_results'}++;
			$stats{'with_filtered_results'}++;
			$call_status = "Yes";
			$filter_status = "Fail";
			$filter_status = "N/A" if(!$self->filtered_validation_file);
			my @results = split(/\t/, $validation_results{$key});

			if($results[12] && ($results[12] =~ 'Germline' || $results[12] =~ 'Somatic' || $results[12] =~ 'Reference' || $results[12] =~ 'LOH' || $results[12] =~ 'IndelFilter' || $results[12] =~ 'Unknown'))
			{
				## STANDARD VARSCAN FORMAT
				$validation_status = $results[12];		
				$varscan_results = join("\t", $results[2], $results[3], $results[4], $results[5], $results[6], $results[7], $results[8], $results[9], $results[10], $results[11], $results[12], $results[13], $results[14]);
				$varscan_freqs = join("\t", $results[6], $results[10]);								
				$normal_coverage = $results[4] + $results[5];
				$tumor_coverage = $results[8] + $results[9];
			}
			else
			{
				## ANNOTATION VARSCAN FORMAT ##
				$validation_status = $results[13];		
				$varscan_results = join("\t", $results[3], $results[4], $results[5], $results[6], $results[7], $results[8], $results[9], $results[10], $results[11], $results[12], $results[13], $results[14], $results[15]);
				$varscan_freqs = join("\t", $results[7], $results[11]);				
				$normal_coverage = $results[5] + $results[6];
				$tumor_coverage = $results[9] + $results[10];
			}
			$varscan_freqs =~ s/\%//g;
		}
		else
		{
			$stats{'with_no_results'}++;
			$call_status = "No";
			$filter_status = $validation_status = "-";
		}
		
		if(!$self->min_coverage || ($tumor_coverage >= $self->min_coverage && $normal_coverage >= $self->min_coverage))
		{
			my $result = join("\t", $call_status, $filter_status, $validation_status);
			$stats{$result}++;
	
			## Print the results to the output file ##
			
			print OUTFILE join("\t", $chrom, $chr_start, $chr_stop, $ref, $var, $result, $varscan_results) . "\n";
	
			## If plotting, print to correct file ##
			
			if($self->output_plot)
			{
				print SOMATIC "$varscan_freqs\n" if($filter_status eq "Pass" && $validation_status eq "Somatic");
				print GERMLINE "$varscan_freqs\n" if($filter_status eq "Pass" && $validation_status eq "Germline");
				print REFERENCE "$varscan_freqs\n" if($filter_status eq "Fail" && $validation_status eq "Reference");
			}			
		}
		else
		{
			$call_status = "No";
			$filter_status = $validation_status = "-";
			my $result = join("\t", $call_status, $filter_status, $validation_status);
			$stats{$result}++;
		}


	}
	
	close($input);
	
	close(SOMATIC);
	close(GERMLINE);
	close(REFERENCE);
	close(OUTFILE);
	
	if($self->output_plot)
	{
		open(SCRIPT, ">$output_file.R") or die "Can't open Script file: $!\n";

		## Get length of germline file ##
		
		my $germline_length = `cat $output_file.GermlineFreqs | wc -l`;
		chomp($germline_length);

		## IF we have germline calls, print those too ##
		if($germline_length) #$stats{"Yes\tPass\tGermline"} && $stats{"Yes\tPass\tGermline"} > 0)
		{
			print SCRIPT qq{
somatic <- read.table("$output_file.SomaticFreqs")
germline <- read.table("$output_file.GermlineFreqs")
reference <- read.table("$output_file.ReferenceFreqs")
png("$output_file.FreqPlot.jpg", height=600, width=600)
plot(germline\$V1, germline\$V2, col="blue", cex=0.75, cex.axis=1.5, cex.lab=1.5, pch=19, xlim=c(0,100), ylim=c(0,100), xlab="Normal", ylab="Tumor")
points(somatic\$V1, somatic\$V2, col="red", cex=0.75, cex.axis=1.5, cex.lab=1.5, pch=19, xlim=c(0,100), ylim=c(0,100))
points(reference\$V1, reference\$V2, col="black", cex=0.75, cex.axis=1.5, cex.lab=1.5, pch=19, xlim=c(0,100), ylim=c(0,100))
dev.off()
			};


		}
		## Otherwise print just Somatic and Reference ##
		else
		{
		print SCRIPT qq{
somatic <- read.table("$output_file.SomaticFreqs")
reference <- read.table("$output_file.ReferenceFreqs")
png("$output_file.FreqPlot.jpg", height=600, width=600)
plot(somatic\$V1, somatic\$V2, col="red", cex=0.75, cex.axis=1.5, cex.lab=1.5, pch=19, xlim=c(0,100), ylim=c(0,100), xlab="Normal", ylab="Tumor")
points(reference\$V1, reference\$V2, col="black", cex=0.75, cex.axis=1.5, cex.lab=1.5, pch=19, xlim=c(0,100), ylim=c(0,100))
dev.off()
		};

		
		}

		## Also do somatic sites by themselves ##

		print SCRIPT qq{
png("$output_file.FreqPlot.Somatic.jpg", height=600, width=600)
plot(somatic\$V1, somatic\$V2, col="red", cex=0.75, cex.axis=1.5, cex.lab=1.5, pch=19, xlim=c(0,100), ylim=c(0,100), xlab="Normal", ylab="Tumor")
dev.off()
		};



		
		close(SCRIPT);




		system("R --no-save <$output_file.R 2>/dev/null");
		system("rm -rf $output_file.R");
	}
	
	## Remove the intermediate files ##
	system("rm -rf $output_file.SomaticFreqs");
	system("rm -rf $output_file.GermlineFreqs");
	system("rm -rf $output_file.ReferenceFreqs");
	
	print $stats{'num_variants'} . " variants in $variants_file\n";
#	print $stats{'with_no_results'} . " had no validation results\n";
#	print $stats{'with_filtered_results'} . " had post-filter validation results\n";
#	print $stats{'with_unfiltered_results'} . " had unfiltered validation results\n";

	## Print all variants with their filter and somatic status ##
	print "COUNT\tCALL\tFILTER\tSTATUS\n";

	foreach my $key (sort keys %stats)
	{
		print "$stats{$key}\t$key\n" if($key =~ 'Yes' || $key =~ 'No');
	}

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



################################################################################################
# Process results - filter variants by type and into high/low confidence
#
################################################################################################

sub load_validation_results
{
	my $filename = shift(@_);
	
	my %results = ();
	
	my $input = new FileHandle ($filename);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $chrom, my $position, my $chr_stop) = split(/\t/, $line);
		
		my $key = join("\t", $chrom, $position);

		## IF this was NOT annotation format (chrom start stop), make it so ##
		
		if($position ne $chr_stop  && 0)
		{
			my $newline = "";
			my @lineContents = split(/\t/, $line);
			my $numContents = @lineContents;
			
			$newline = "$lineContents[0]\t$lineContents[1]\t$lineContents[1]";
			for(my $colCounter = 2; $colCounter < $numContents; $colCounter++)
			{
				$newline .= "\t$lineContents[$colCounter]";
			}
			
			$results{$key} = $newline;
		}
		else
		{
			$results{$key} = $line;			
		}
		

	}
	
	close($input);	

	return(%results);
}


1;

