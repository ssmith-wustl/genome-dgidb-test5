
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
		status_file	=> { is => 'Text', doc => "File containing varscan calls, e.g. status.varscan.snp" , is_optional => 0, is_input => 1},
		report_only	=> { is => 'Text', doc => "If set to 1, will not produce output files" , is_optional => 1},
		somatic_out	=> { is => 'Text', doc => "DO NOT USE: Output name for Somatic calls [status_file.Somatic]" , is_optional => 1, is_input => 1, is_output => 1},
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
	my $status_file = $self->status_file;
	$report_only = $self->report_only if($self->report_only);

	if(-e $status_file)
	{
		process_results($status_file);
	}
	else
	{
		die "Status file $status_file not found!\n";
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
	$variants_by_status{'Somatic'} = $variants_by_status{'Germline'} = $variants_by_status{'LOH'} = '';
	
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
			my $somatic_status = "";
			if($lineContents[13] && ($lineContents[13] =~ "Reference" || $lineContents[13] =~ "Somatic" || $lineContents[13] =~ "Germline" || $lineContents[13] =~ "Unknown" || $lineContents[13] =~ "LOH"))
			{
				$somatic_status = $lineContents[13];	
			}
			elsif($lineContents[12] && ($lineContents[12] =~ "Reference" || $lineContents[12] =~ "Somatic" || $lineContents[12] =~ "Germline" || $lineContents[12] =~ "Unknown" || $lineContents[12] =~ "LOH"))
			{
				$somatic_status = $lineContents[12];
			}
			else
			{
				warn "Unable to parse somatic_status from file $variants_file line $lineCounter\n";
				$somatic_status = "Unknown";
			}

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
				open(STATUS, ">$variants_file.$status") or die "Can't open output file: $!\n";
				open(HICONF, ">$variants_file.$status.hc") or die "Can't open output file: $!\n";
				open(LOWCONF, ">$variants_file.$status.lc") or die "Can't open output file: $!\n";
				print HICONF "$file_header\n";
				print LOWCONF "$file_header\n";
				print STATUS "$file_header\n";
			}
			
			my $numHiConf = my $numLowConf = 0;
			
			foreach my $line (@lines)
			{
				my @lineContents = split(/\t/, $line);
				my $numContents = @lineContents;
				
				my $somatic_status = my $p_value = "";
				
				## Get Somatic status and p-value ##
				
				for(my $colCounter = 4; $colCounter < $numContents; $colCounter++)
				{
					if($lineContents[$colCounter])
					{
						my $value = $lineContents[$colCounter];
						
						if($value eq "Reference" || $value eq "Somatic" || $value eq "Germline" || $value eq "LOH" || $value eq "Unknown")
						{
							$somatic_status = $value;
							$p_value = $lineContents[$colCounter + 1];
							$p_value = $lineContents[$colCounter + 2] if($lineContents[$colCounter + 2] && $lineContents[$colCounter + 2] < $p_value);
						}
					}
				}
				
				## Print to master status file ##
				print STATUS "$line\n" if(!$report_only);
				
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

