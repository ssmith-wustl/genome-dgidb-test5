
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
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		validation_file		=> { is => 'Text', doc => "VarScan output file for validation data", is_optional => 0 },
		filtered_validation_file		=> { is => 'Text', doc => "VarScan calls passing strand-filter in validation BAM (recommended)", is_optional => 0 },
		variants_file 	=> { is => 'Text', doc => "File of variants to report on", is_optional => 0 },
		output_file 	=> { is => 'Text', doc => "Output file for validation results", is_optional => 0 },
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
	
	open(OUTFILE, ">$output_file") or die "Can't open outfile: $!\n";
	print OUTFILE "chrom\tchr_start\tchr_stop\tref\tvar\tcalled\tfilter\tstatus\tv_ref\tv_var\tnorm_reads1\tnorm_reads2\tnorm_freq\tnorm_call\ttum_reads1\ttum_reads2\ttum_freq\ttum_call\tsomatic_status\tgermline_p\tsomatic_p\n";

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
		$lineCounter++;
		
		my ($chrom, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $line);
		
		my $key = join("\t", $chrom, $chr_start);
		$stats{'num_variants'}++;
		
		my $call_status = my $filter_status = my $validation_status = "";
		my $varscan_results = "";
		
		if($filtered_results{$key})
		{
			$stats{'with_filtered_results'}++;
			$call_status = "Yes";
			$filter_status = "Pass";
			my @results = split(/\t/, $filtered_results{$key});
			$validation_status = $results[13];
			$varscan_results = join("\t", $results[3], $results[4], $results[5], $results[6], $results[7], $results[8], $results[9], $results[10], $results[11], $results[12], $results[13], $results[14], $results[15]);
		}
		elsif($validation_results{$key})
		{
			$stats{'with_unfiltered_results'}++;
			$stats{'with_filtered_results'}++;
			$call_status = "Yes";
			$filter_status = "Fail";
			$filter_status = "N/A" if(!$self->filtered_validation_file);
			my @results = split(/\t/, $validation_results{$key});
			$validation_status = $results[13];
			$varscan_results = join("\t", $results[3], $results[4], $results[5], $results[6], $results[7], $results[8], $results[9], $results[10], $results[11], $results[12], $results[13], $results[14], $results[15]);
		}
		else
		{
			$stats{'with_no_results'}++;
			$call_status = "No";
			$filter_status = $validation_status = "-";
		}
		
		my $result = join("\t", $call_status, $filter_status, $validation_status);
		$stats{$result}++;

		## Print the results to the output file ##
		
		print OUTFILE join("\t", $chrom, $chr_start, $chr_stop, $ref, $var, $result, $varscan_results) . "\n";
	}
	
	close($input);
	
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
		
		(my $chrom, my $position) = split(/\t/, $line);
		
		my $key = join("\t", $chrom, $position);
		
		$results{$key} = $line;
	}
	
	close($input);	

	return(%results);
}


1;

