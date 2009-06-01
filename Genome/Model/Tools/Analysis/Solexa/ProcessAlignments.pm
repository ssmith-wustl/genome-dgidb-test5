
package Genome::Model::Tools::Analysis::Solexa::ProcessAlignments;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# LoadReads - Run maq sol2sanger on Illumina/Solexa files in a gerald_directory
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
use Cwd;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Analysis::Solexa::ProcessAlignments {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		flowcell_id	=> { is => 'Text', doc => "Search by flowcell_id", is_optional => 1 },
		sample_name	=> { is => 'Text', doc => "Search by sample name", is_optional => 1 },
		library_name	=> { is => 'Text', doc => "Search by library name" , is_optional => 1},
		include_lanes	=> { is => 'Text', doc => "Specify which lanes of a flowcell to include [e.g. 1,2,3]" , is_optional => 1},
		output_dir	=> { is => 'Text', doc => "Output dir containing the fastq_dir" , is_optional => 1},
		aligner	=> { is => 'Text', doc => "Alignment tool to use (bowtie|maq|novoalign) [bowtie]" , is_optional => 1},
		match_to_regions	=> { is => 'Text', doc => "A file of regions to match alignments against" , is_optional => 1},
		output_name	=> { is => 'Text', doc => "A string for naming output files e.g. layers" , is_optional => 1},
		varscan_roi	=> { is => 'Text', doc => "Run varscan on ROI file" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Obtains reads from a flowcell_id in FastQ format"                 
}

sub help_synopsis {
    return <<EOS
This command aligns reads to Hs36 (by default) after you've run load-reads
EXAMPLE 1:	gt analysis solexa align-reads --flowcell_id 302RT --include-lanes 1,2,3,4 --output-dir output_dir --aligner bowtie
EXAMPLE 2:	gt analysis solexa align-reads --sample-name H_GP-0365n --output-dir H_GP-0365n
EXAMPLE 3:	gt analysis solexa align-reads --library-name H_GP-0365n-lib2 --output-dir H_GP-0365n
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
	my $flowcell_id = $self->flowcell_id;
	my $sample_name = $self->sample_name;
	my $library_name = $self->library_name;
	my $aligner = "bowtie";
	$aligner = $self->aligner if($self->aligner);
	my $output_dir = "./";
	$output_dir = $self->output_dir if($self->output_dir);
	my $output_name;
	$output_name = $self->output_name if($self->output_name);
	my $match_to_regions;
	$match_to_regions = $self->match_to_regions if($self->match_to_regions);
	my $varscan_roi;
	$varscan_roi = $self->varscan_roi if($self->varscan_roi);

	## Handle include-lanes when specified ##

	my $include_lanes;
	$include_lanes = $self->include_lanes if($self->include_lanes);
	my %lanes_to_include = ();
	
	if($include_lanes)
	{
		my @lanes = split(/\,/, $include_lanes);
		foreach my $desired_lane (@lanes)
		{
			$lanes_to_include{$desired_lane} = 1;
		}
	}
	

	## Get current directory ##
	
	my $cwd = getcwd;

	my $sqlrun, my $rows_returned, my $cmd;

	if($flowcell_id)
	{
		$sqlrun = `sqlrun "select flow_cell_id, lane, sample_name, library_name, read_length, filt_clusters, seq_id, gerald_directory, median_insert_size, filt_aligned_clusters_pct from solexa_lane_summary where flow_cell_id = '$flowcell_id' ORDER BY flow_cell_id, lane" --instance warehouse --parse`;
	}

	if($sample_name)
	{
		$sqlrun = `sqlrun "select flow_cell_id, lane, sample_name, library_name, read_length, filt_clusters, seq_id, gerald_directory, median_insert_size, filt_aligned_clusters_pct from solexa_lane_summary where sample_name LIKE '\%$sample_name\%' ORDER BY lane" --instance warehouse --parse`;
	}

	if($library_name)
	{
		$sqlrun = `sqlrun "select flow_cell_id, lane, sample_name, library_name, read_length, filt_clusters, seq_id, gerald_directory, median_insert_size, filt_aligned_clusters_pct from solexa_lane_summary where library_name = '$library_name' ORDER BY lane" --instance warehouse --parse`;
	}

	if($sqlrun)
	{
#		print "$sqlrun\n"; exit(0);
		
		print "fcell\tlane\tlibrary_type\tfilt_reads\taln%\tsample_name\tlibrary_name\tstatus\n";
		
		my @lines = split(/\n/, $sqlrun);
		my %lane_pairs = ();
		
		foreach my $line (@lines)
		{
			if($line && (substr($line, 0, 4) eq "FLOW" || substr($line, 0, 1) eq "-"))
			{
				
			}
			elsif($line && $line =~ "Execution")
			{
				($rows_returned) = split(/\s+/, $line);
				print "$rows_returned rows returned\n";
			}
			elsif($line)
			{
				(my $flowcell, my $lane, my $sample, my $library, my $read_length, my $filt_clusters, my $seq_id, my $gerald_dir, my $insert_size, my $align_pct) = split(/\t/, $line);
				
				## Proceed if lane to be included ##
				if(!$include_lanes || $lanes_to_include{$lane})
				{
					## Get num reads ##
					
					my $num_reads = commify($filt_clusters);
					$align_pct = 0 if(!$align_pct);
					$align_pct = sprintf("%.2f", $align_pct) . '%';
					
					## Get SE or PE ##
					
					my $end_type = "SE";
					my $lane_name = $lane;
	
					if($insert_size)
					{
						$end_type = "PE";
						$lane_pairs{"$flowcell.$lane"} = 1 if(!$lane_pairs{"$flowcell.$lane"});
						$lane_name .= "_" . $lane_pairs{"$flowcell.$lane"};
						$lane_pairs{"$flowcell.$lane"}++;
					}
					
					## Create flowcell output dir and fastq output dir if necessary ##
					
					my $flowcell_dir = $output_dir . "/" . $flowcell;
					my $fastq_dir = $output_dir . "/" . $flowcell . "/fastq_dir";
					my $output_fastq = $fastq_dir . "/" . "s_" . $lane_name . "_sequence.fastq";
					
					## Create the output_dir ##
					
					my $alignment_dir = $flowcell_dir . "/" . $aligner . "_out";
					mkdir($alignment_dir) if(!(-d $alignment_dir));

					my $alignment_outfile = $flowcell_dir . "/" . $aligner . "_out/" . "s_" . $lane_name . "_sequence.bowtie";
					my $alignment_logfile = $flowcell_dir . "/" . $aligner . "_out/" . "s_" . $lane_name . "_sequence.bowtie.log";

					## Print result ##
					if(-e $output_fastq && -e $alignment_outfile)
					{
						$num_reads =~ s/[^0-9]//g;

						## Run the alignment ##
						my $align_result = "";
						
						if($aligner eq "bowtie")
						{
							## Calculate the reads aligned from Bowtie output ##
							my $reads_aligned = my $new_align_pct = "?";
							
							if(-e $alignment_logfile)
							{
								$reads_aligned = `grep Reported $alignment_logfile | grep output`;
								my @temp = split(/\s+/, $reads_aligned);
								$reads_aligned = $temp[1];
								if($reads_aligned)
								{
									$align_result .= commify($reads_aligned);
									$new_align_pct = sprintf("%.2f", ($reads_aligned / $num_reads * 100)) . '%';
									$align_result .= "\t$new_align_pct";
								}
							}
							
							$align_result .= "\t$alignment_outfile";

							print "$flowcell\t$lane_name\t$read_length bp $end_type\t$sample\t" . commify($num_reads) . "\t$align_result\n";
							
							
							## Launch required processing steps ##
							
							if($match_to_regions)
							{
								my $output_roi = my $output_layers = "";
								$output_roi = $alignment_outfile . ".roi";
								$output_layers = $alignment_outfile . ".layers";
								if($output_name)
								{
									$output_roi = $alignment_outfile . ".$output_name.roi";
									$output_layers = $alignment_outfile . ".$output_name.layers";
								}
								$cmd = "gt bowtie match-to-regions --regions-file $match_to_regions --alignments-file $alignment_outfile --output-file $output_roi --output-layers $output_layers";
								print "$cmd\n";
								system("bsub -q short -oo $output_roi.out -R\"select[mem>2000] rusage[mem=2000]\" $cmd");
							}

							if($varscan_roi)
							{
								## Create varscan dir if necessary ##
								my $varscan_dir = $flowcell_dir . "/varscan_out";
								mkdir($varscan_dir) if(!(-d $varscan_dir));
								
								my $varscan_sample = "s_" . $lane_name . "_sequence.bowtie";
								
								my $roi_file = "$alignment_outfile.roi";
								if(-e $roi_file)
								{
									$cmd = "varscan easyrun $roi_file --output-dir $varscan_dir --sample $varscan_sample --min-coverage 10 --min-var-freq 0.25";
									system("bsub -q long -R\"select[mem>4000] rusage[mem=4000]\" $cmd");
								}
							}
							
							## Launch PE ##
							if($end_type eq "PE" && $lane_pairs{"$flowcell.$lane"} eq "2")
							{
								my $paired_outfile = $flowcell_dir . "/" . $aligner . "_out/" . "s_" . $lane . "_paired.bowtie";
								my $paired_logfile = $flowcell_dir . "/" . $aligner . "_out/" . "s_" . $lane . "_paired.bowtie.log";

#								$num_reads = $num_reads * 2;
#								$num_reads = commify($num_reads);
#
#								$reads_aligned = "";
#								if(-e $alignment_logfile)
#								{
#									$reads_aligned = `grep Reported $paired_logfile | grep output`;
#									my @temp = split(/\s+/, $reads_aligned);
#									$reads_aligned = 2 * $temp[1];
#									$reads_aligned = commify($reads_aligned);
#								}
#
#								print "$flowcell\t$lane\t$read_length bp PE\t$sample\t$num_reads\t$reads_aligned\t$paired_outfile\n";
							}
						}
					}
					else
					{
						print "$flowcell \t$lane_name \t$read_length bp $end_type\t$num_reads \t$sample \tAlignment_file_not_found\n";
					}

				}
			}
		}
	}

	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}

sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;

