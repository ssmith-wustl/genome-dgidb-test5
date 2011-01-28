
package Genome::Model::Tools::SnpArray::MergeSegments;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# MergeSegments - merges adjoining segments of similar copy number; distinguishes amplifications and deletions
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

my %stats = ();

class Genome::Model::Tools::SnpArray::MergeSegments {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		segments_file	=> { is => 'Text', doc => "Segments with p-values from running CBS on data", is_optional => 0, is_input => 1 },		
		amp_threshold	=> { is => 'Text', doc => "Minimum seg_mean threshold for amplification", is_optional => 1, is_input => 1, default => 0.25},
		del_threshold	=> { is => 'Text', doc => "Maximum seg_mean threshold for deletion", is_optional => 1, is_input => 1, default => -0.25},
		size_threshold	=> { is => 'Text', doc => "Fraction of chromosome length above which an event is considered large-scale", is_input => 1, default => 0.25},
		output_basename	=> { is => 'Text', doc => "Base name for output", is_optional => 1, is_input => 1},
		ref_sizes 	=> { is => 'Text', doc => "Two column file of reference name and size in bp for calling by chromosome arm", default => "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/ref_list_for_bam"},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Merges adjoining segments of similar copy number"                 
}

sub help_synopsis {
    return <<EOS
This command merges merges adjoining CBS segments of similar copy number and distinguishes amplifications and deletions
EXAMPLE:	gmt snp-array merge-adjoining-segments --segments-file snpArray.cbs.segments.tsv --output-basename snpArray.cbs.segments-merged
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

sub execute
{                               # replace with real execution logic.
	my $self = shift;

	## Get required parameters ##
	my $segments_file = $self->segments_file;
	my $ref_sizes_file = $self->ref_sizes;
	my $output_basename = $self->output_basename;

	## Get thresholds ##
	
	my $amp_threshold = $self->amp_threshold;
	my $del_threshold = $self->del_threshold;
	my $size_threshold = $self->size_threshold;

	my %ref_sizes = parse_ref_sizes($ref_sizes_file);
	my %stats = ();
	$stats{'num_segments'} = $stats{'num_amps'} = $stats{'num_dels'} = $stats{'num_neutral'} = 0;
	$stats{'total_bp'} = $stats{'amp_bp'} = $stats{'del_bp'} = $stats{'neutral_bp'} = 0;

	## Open outfile for amps and dels ##
	
	open(AMPSDELS, ">$output_basename.events.tsv") or die "Can't open outfile: $!\n";
	

	## Parse the segments file ##

	my $input = new FileHandle ($segments_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my ($id, $sample, $chrom, $chr_start, $chr_stop, $num_mark, $seg_mean, $bstat, $p_value, $lcl, $ucl) = split(/\t/, $line);

		if($chrom && $chrom eq "chrom")
		{
			## Print header 
			print AMPSDELS "$line\tevent_size\tevent_type\n";
		}
		elsif($chrom && $chrom ne "chrom")
		{
			$stats{'num_segments'}++;
			
			$chrom = "X" if($chrom eq "23");
			$chrom = "Y" if($chrom eq "24");

			## Determine size ##
			
			my $event_size = $chr_stop - $chr_start + 1;
			$stats{'total_bp'} += $event_size;

			## Determine size category ##
			
			my $size_category = "focal";

			my $chrom_fraction = "";

			if($ref_sizes{$chrom})
			{
				$chrom_fraction = $event_size / $ref_sizes{$chrom};
				if($chrom_fraction && $chrom_fraction >= $size_threshold)
				{
					$size_category = "large-scale";
				}
			}
			
			
			
			## Determine copy number class ##
			
			my $copy_class = "neutral";
			
			if($seg_mean >= $amp_threshold)
			{
				$copy_class = "amplification";
				$stats{'num_amps'}++;
				$stats{'amp_bp'} += $event_size;
				$stats{"$size_category\t$copy_class"}++;
				print AMPSDELS join("\t", $line, $size_category, $copy_class) . "\n";
			}
			elsif($seg_mean <= $del_threshold)
			{
				$copy_class = "deletion";
				$stats{'num_dels'}++;
				$stats{'del_bp'} += $event_size;
				$stats{"$size_category\t$copy_class"}++;
				print AMPSDELS join("\t", $line, $size_category, $copy_class) . "\n";
			}
			else
			{
				$stats{'num_neutral'}++;
				$stats{'neutral_bp'} += $event_size;
			}
			
#			print join("\t", $chrom, $chr_start, $chr_stop, $num_mark, $seg_mean, $p_value, $size_category, $copy_class) . "\n";
		}
		

	}
	close($input);

	## Determine base pair fractions ##
	my $pct_amp_bp = my $pct_del_bp = my $pct_neutral_bp = "-";
	$pct_amp_bp = sprintf("%.2f", $stats{'amp_bp'} / $stats{'total_bp'} * 100) . '%';
	$pct_del_bp = sprintf("%.2f", $stats{'del_bp'} / $stats{'total_bp'} * 100) . '%';
	$pct_neutral_bp = sprintf("%.2f", $stats{'neutral_bp'} / $stats{'total_bp'} * 100) . '%';

	open(SUMMARY, ">$output_basename.summary.txt") or die "Can't open summary file: $!\n";
	print SUMMARY "segments\tneutral\tnum_neutral_bp\tpct_neutral_bp\t";
	print SUMMARY "amplifications\tlarge_scale_amps\tfocal_amps\tnum_amp_bp\tpct_amp_bp\t";
	print SUMMARY "deletions\tlarge_scale_dels\tfocal_dels\tnum_del_bp\tpct_del_bp\t";
	print SUMMARY "\n";

	print SUMMARY join("\t", $stats{'num_segments'}, $stats{'num_neutral'}, $stats{'neutral_bp'}, $pct_neutral_bp) . "\t";
	print SUMMARY join("\t", $stats{'num_amps'}, $stats{"large-scale\tamplification"}, $stats{"focal\tamplification"}, $stats{'amp_bp'}, $pct_amp_bp) . "\t";
	print SUMMARY join("\t", $stats{'num_dels'}, $stats{"large-scale\tdeletion"}, $stats{"focal\tdeletion"}, $stats{'del_bp'}, $pct_del_bp);
	print SUMMARY "\n";


#	print "$lineCounter lines parsed\n";
	print $stats{'num_segments'} . " segments\n";
	print $stats{'num_neutral'} . " ($pct_neutral_bp bp) were neutral\n";

	print $stats{'num_amps'} . " ($pct_amp_bp bp) classified as amplifications\n";
	print "\t" . $stats{"large-scale\tamplification"} . " large-scale events\n";
	print "\t" . $stats{"focal\tamplification"} . " focal events\n";

	print $stats{'num_dels'} . " ($pct_del_bp bp) classified as deletions\n";
	print "\t" . $stats{"large-scale\tdeletion"} . " large-scale events\n";
	print "\t" . $stats{"focal\tdeletion"} . " focal events\n";


	close(SUMMARY);
}



################################################################################################
# Execute - the main program logic
#
################################################################################################

sub parse_ref_sizes
{                               # replace with real execution logic.
	my $FileName = shift(@_);

	my %sizes = ();

	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		my ($ref_name, $ref_size) = split(/\s+/, $line);
		$sizes{$ref_name} = $ref_size;
	}
	
	close($input);
	
	return(%sizes);
}


###############################################################################
# commify - add appropriate commas to long integers
###############################################################################

sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;

