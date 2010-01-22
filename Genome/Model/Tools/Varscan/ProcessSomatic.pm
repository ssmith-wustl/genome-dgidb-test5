
package Genome::Model::Tools::Varscan::ProcessSomatic;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# Varscan::ProcessSomatic	Process somatic pipeline output
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	12/29/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it


my $report_only = 0;

class Genome::Model::Tools::Varscan::ProcessSomatic {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		output	=> { is => 'Text', doc => "Basename for output, eg. varscan_out/varscan.status" , is_optional => 0},
		report_only	=> { is => 'Text', doc => "If set to 1, will not produce output files" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Process output from VarScan somatic"                 
}

sub help_synopsis {
    return <<EOS
Processes output from VarScan somatic
EXAMPLE:	gmt varscan process-somatic ...
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
	my $output = $self->output;
	$report_only = $self->report_only if($self->report_only);

	if(-e "$output.snp" && -e "$output.indel")
	{
		process_results("$output.snp");
		process_results("$output.indel");		
	}
	else
	{
		die "Error: One of the output files ($output.snp or $output.indel) is missing!\n";
	}
	
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



################################################################################################
# Process results - filter variants by type and into high/low confidence
#
################################################################################################

sub process_results
{
	my $variants_file = shift(@_);
	my $file_header = "chrom\tposition";

	print "Processing variants in $variants_file...\n";

	my %variants_by_status = ();
	
	## Parse the variant file ##

	my $input = new FileHandle ($variants_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		my @lineContents = split(/\t/, $line);
		
		if(($lineContents[0] eq "chrom" || $lineContents[0] eq "ref_name"))
		{
			$file_header = $line;
		}
		else
		{
			my $somatic_status = $lineContents[12];
			$variants_by_status{$somatic_status} .= "\n" if($variants_by_status{$somatic_status});
			$variants_by_status{$somatic_status} .= $line;
		}
	}
	
	close($input);
	
	
	foreach my $status (keys %variants_by_status)
	{
		my @lines = split(/\n/, $variants_by_status{$status});
		my $num_lines = @lines;
		print "$num_lines $status\n";
		
		## Output Germline, Somatic, and LOH ##

		if($status eq "Germline" || $status eq "Somatic" || $status eq "LOH")
		{
			if(!$report_only)
			{
				open(HICONF, ">$variants_file.$status.high_conf") or die "Can't open output file: $!\n";
				open(LOWCONF, ">$variants_file.$status.low_conf") or die "Can't open output file: $!\n";
				print HICONF "$file_header\n";
				print LOWCONF "$file_header\n";
			}
			
			my $numHiConf = my $numLowConf = 0;
			
			foreach my $line (@lines)
			{
				my @lineContents = split(/\t/, $line);
				my $somatic_status = $lineContents[12];
				my $p_value = 1;
				
				if($lineContents[14] && ($somatic_status eq "LOH" || $somatic_status eq "Somatic"))
				{
					$p_value = $lineContents[14];
				}
				else
				{
					$p_value = $lineContents[13];
				}
				
				if($p_value <= 1.0E-06)
				{
					print HICONF "$line\n" if(!$report_only);
					$numHiConf++;
				}
				else
				{
					print LOWCONF "$line\n" if(!$report_only);
					$numLowConf++;
				}
			}
			
			close(HICONF);
			close(LOWCONF);
			
			print "\t$numHiConf high confidence\n";
			print "\t$numLowConf low confidence\n";
		}
		
	}
	
}


1;

