
package Genome::Model::Tools::SnpArray::CompareCopySegments;     # rename this when you give the module file a different name <--

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

class Genome::Model::Tools::SnpArray::CompareCopySegments {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		array_events	=> { is => 'Text', doc => "List of merged CNA events from SNP array data, e.g. snpArray.cbs.segments.events.tsv", is_optional => 0, is_input => 1 },
		sequence_events	=> { is => 'Text', doc => "List of merged CNA events from SNP array data, e.g. varScan.output.copynumber.cbs.segments.events.tsv", is_optional => 0, is_input => 1 },
		event_size	=> { is => 'Text', doc => "Specify large-scale or focal", is_optional => 1, is_input => 1},
		output_file	=> { is => 'Text', doc => "Output file for comparison result", is_optional => 1, is_input => 1},
		output_hits	=> { is => 'Text', doc => "Output file shared events", is_optional => 1, is_input => 1},
		output_misses	=> { is => 'Text', doc => "Output file for events from only one source", is_optional => 1, is_input => 1},
		verbose	=> { is => 'Text', doc => "Prints verbosely if set to 1", is_optional => 1, is_input => 1}
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Compares copy number alterations detected by SNP array versus sequence data"                 
}

sub help_synopsis {
    return <<EOS
This command compares copy number alterations detected by SNP array versus sequence data
EXAMPLE:	gmt snp-array compare-copy-segments --array-events snpArray.cbs.segments.events.tsv --sequence-events varScan.output.copynumber.cbs.segments.events.tsv
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
	my $array_events_file = $self->array_events;
	my $sequence_events_file = $self->sequence_events;
	my $output_file = $self->output_file;

	my %stats = ();
	$stats{'num_sequence_events'} = $stats{'num_supported_by_array'} = $stats{'num_sequence_amps'} = $stats{'num_amps_supported_by_array'} = $stats{'num_sequence_dels'} = $stats{'num_dels_supported_by_array'} = $stats{'num_array_events'} = $stats{'num_supported_by_sequence'} = $stats{'num_array_amps'} = $stats{'num_amps_supported_by_sequence'} = $stats{'num_array_dels'} = $stats{'num_dels_supported_by_sequence'} = 0;		

	print "Loading SNP array events...\n" if($self->verbose);
	my %array_events = load_events($array_events_file, $self);

	print "Loading sequence events...\n" if($self->verbose);
	my %sequence_events = load_events($sequence_events_file, $self);

	## Open hits and misses files if specified ##
	
	if($self->output_hits)
	{
		open(HITS, ">" . $self->output_hits) or die "Can't open outfile: $!\n";
	}

	if($self->output_misses)
	{
		open(MISSES, ">" . $self->output_misses) or die "Can't open outfile: $!\n";
	}



	## Go through the events by chromosome ##
	
	foreach my $chrom (sort keys %array_events)
	{
		if($array_events{$chrom} && $sequence_events{$chrom})
		{
			## Comparison 1: Specificity: How many Sequence-based Events are Supported by Array Calls? ##
			## The third parameter (1) tells it to print overlaps ##
			my %chrom_stats = compare_events($array_events{$chrom}, $sequence_events{$chrom}, 0);

			## Update the Overall Totals ##
			$stats{'num_sequence_events'} += $chrom_stats{'num_events'};
			$stats{'num_sequence_amps'} += $chrom_stats{'num_amps'};
			$stats{'num_sequence_dels'} += $chrom_stats{'num_dels'};

			$stats{'num_supported_by_array'} += $chrom_stats{'num_supported'};
			$stats{'num_amps_supported_by_array'} += $chrom_stats{'num_amps_supported'};
			$stats{'num_dels_supported_by_array'} += $chrom_stats{'num_dels_supported'};

#			print join("\t", $chrom, $chrom_stats{'num_events'}, $chrom_stats{'num_supported'}) . "\n";

			## Print hits and misses ##
		
			if($self->output_hits)
			{
				print HITS "$chrom_stats{'hits'}";
			}
		
			if($self->output_misses)
			{
				print MISSES "$chrom_stats{'misses'}";
			}
			

			## Comparison 2: Sensitivity: How many Array-based Events are Detected by Sequence calls? ##
			%chrom_stats = ();
			%chrom_stats = compare_events($sequence_events{$chrom}, $array_events{$chrom}, 0);
			$stats{'num_array_events'} += $chrom_stats{'num_events'};
			$stats{'num_array_amps'} += $chrom_stats{'num_amps'};
			$stats{'num_array_dels'} += $chrom_stats{'num_dels'};			

			$stats{'num_supported_by_sequence'} += $chrom_stats{'num_supported'};
			$stats{'num_amps_supported_by_sequence'} += $chrom_stats{'num_amps_supported'};
			$stats{'num_dels_supported_by_sequence'} += $chrom_stats{'num_dels_supported'};			



		}
	}

	print "TOTAL:\n";

	if($self->output_file)
	{
		open(OUTFILE, ">" . $output_file) or die "Can't open outfile: $!\n";
		print OUTFILE "sequence_events\tsupported_by_array\tamps\tsupported\tdels\tsupported\tarray_events\tdetected_by_sequence\tamps\tdetected\tdels\tdetected\n";
		print OUTFILE join("\t", $stats{'num_sequence_events'}, $stats{'num_supported_by_array'}, $stats{'num_sequence_amps'}, $stats{'num_amps_supported_by_array'}, $stats{'num_sequence_dels'}, $stats{'num_dels_supported_by_array'});
		print OUTFILE "\t";
		print OUTFILE join("\t", $stats{'num_array_events'}, $stats{'num_supported_by_sequence'}, $stats{'num_array_amps'}, $stats{'num_amps_supported_by_sequence'}, $stats{'num_array_dels'}, $stats{'num_dels_supported_by_sequence'});
		print OUTFILE "\n";
		close(OUTFILE);
	}


	if($self->output_hits)
	{
		close(HITS);
	}

	if($self->output_misses)
	{
		close(MISSES);
	}

	print $stats{'num_supported_by_array'} . " of " . $stats{'num_sequence_events'} . " sequence events supported by array\n";	
	print $stats{'num_amps_supported_by_array'} . " of " . $stats{'num_sequence_amps'} . " sequence amplifications supported by array\n";	
	print $stats{'num_dels_supported_by_array'} . " of " . $stats{'num_sequence_dels'} . " sequence deletions supported by array\n";	

	print "\n";

	print $stats{'num_supported_by_sequence'} . " of " . $stats{'num_array_events'} . " array events supported by sequence\n";	
	print $stats{'num_amps_supported_by_sequence'} . " of " . $stats{'num_array_amps'} . " array amplifications supported by sequence\n";	
	print $stats{'num_dels_supported_by_sequence'} . " of " . $stats{'num_array_dels'} . " array deletions supported by sequence\n";	


	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


################################################################################################
# Load Genotypes
#
################################################################################################

sub load_events
{                               # replace with real execution logic.
	my $events_file = shift(@_);
	my $self = shift(@_);
	my %events = ();

	my %type_counts = ();
	
	my $input = new FileHandle ($events_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		if($lineCounter > 1)
		{
#			my ($id, $sample, $chrom, $chr_start, $chr_stop, $num_mark, $seg_mean, $bstat, $p_value, $lcl, $ucl, $event_size, $event_type) = split(/\t/, $line);
#chrom\tchr_start\tchr_stop\tseg_mean\tnum_segments\tnum_markers\tp_value\tevent_type\tevent_size\tsize_class\tchrom_arm\tarm_fraction\tchrom_fraction
			my ($chrom, $chr_start, $chr_stop, $seg_mean, $num_segments, $num_markers, $p_value, $event_type, $event_size_bp, $event_size, $chrom_arm) = split(/\t/, $line);
			
			if($event_type ne "neutral")
			{
				if(!$self->event_size || $event_size eq $self->event_size)
				{
					$events{$chrom} .= "\n" if($events{$chrom});
					$events{$chrom} .= join("\t", $chrom, $chr_start, $chr_stop, $num_markers, $seg_mean, $p_value, $event_size, $event_type);
				}				
			}


			$type_counts{"$event_size $event_type"}++;
		}

	}
	close($input);


	foreach my $event_type (sort keys %type_counts)
	{
		print "$type_counts{$event_type} $event_type, " if($self->verbose);
	}
	
	print "\n" if($self->verbose);
	
	return(%events);                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




################################################################################################
# Load Genotypes
#
################################################################################################

sub compare_events
{
	my ($array_events, $sequence_events, $print_overlaps) = @_;
	
	my %chrom_stats = ();
	$chrom_stats{'num_events'} = $chrom_stats{'num_supported'} = 0;
	$chrom_stats{'num_amps'} = $chrom_stats{'num_amps_supported'} = 0;
	$chrom_stats{'num_dels'} = $chrom_stats{'num_dels_supported'} = 0;
	
	my @array_events = split(/\n/, $array_events);
	my @sequence_events = split(/\n/, $sequence_events);
	
	foreach my $sequence_event (@sequence_events)
	{
		my ($chrom, $chr_start, $chr_stop, $num_mark, $seg_mean, $p_value, $event_size, $event_type) = split(/\t/, $sequence_event);
		
		$chrom_stats{'num_events'}++;

		if($event_type =~ 'amp')
		{
			$chrom_stats{'num_amps'}++;
		}
		elsif($event_type =~ 'del')
		{
			$chrom_stats{'num_dels'}++;
		}
		
		## Look for supporting events on the array ##
		
		my $array_supported_flag = 0;		
		my $array_overlaps = "";
		
		foreach my $array_event (@array_events)
		{
			my ($array_chrom, $array_chr_start, $array_chr_stop, $array_num_mark, $array_seg_mean, $array_p_value, $array_event_size, $array_event_type) = split(/\t/, $array_event);
			
			
			
			## Match Chromosome ##
			if($array_chrom eq $chrom)
			{
				## Check Positional Overlap ##
				if($array_chr_stop >= $chr_start && $array_chr_start <= $chr_stop)
				{
					if($array_event_type eq $event_type)
					{
						$array_supported_flag++;
						$array_overlaps .= "\n" if($array_overlaps);
						$array_overlaps .= join("\t", "", $array_chrom, $array_chr_start, $array_chr_stop, $array_seg_mean, $array_event_size, $array_event_type);
					}
				}
			}
		}
		
		if($array_supported_flag)
		{
			$chrom_stats{'num_supported'}++;

			if($event_type =~ 'amp')
			{
				$chrom_stats{'num_amps_supported'}++;
			}
			elsif($event_type =~ 'del')
			{
				$chrom_stats{'num_dels_supported'}++;
			}

			if($print_overlaps)
			{
				print join("\t", "EVENT", $chrom, $chr_start, $chr_stop, $seg_mean, $event_size, $event_type) . "\n";
				print $array_overlaps . "\n";
			}

			## Save hits ##
			$chrom_stats{'hits'} .= "\n" if($chrom_stats{'hits'});
			$chrom_stats{'hits'} .= join("\t", "EVENT", $sequence_event) . "\n";
			$chrom_stats{'hits'} .= $array_overlaps;
		}
		else
		{
			## Save misses ##
			$chrom_stats{'misses'} .= "\n" if($chrom_stats{'misses'});
			$chrom_stats{'misses'} .= join("\t", "EVENT", $sequence_event) . "\n";
		}
	}
	
	return(%chrom_stats);
}


sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;

