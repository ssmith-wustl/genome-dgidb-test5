
package Genome::Model::Tools::Analysis::Solexa::AlignReads;     # rename this when you give the module file a different name <--

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

class Genome::Model::Tools::Analysis::Solexa::AlignReads {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		flowcell_id	=> { is => 'Text', doc => "Search by flowcell_id", is_optional => 1 },
		sample_name	=> { is => 'Text', doc => "Search by sample name", is_optional => 1 },
		library_name	=> { is => 'Text', doc => "Search by library name" , is_optional => 1},
		include_lanes	=> { is => 'Text', doc => "Specify which lanes of a flowcell to include [e.g. 1,2,3]" , is_optional => 1},
		output_dir	=> { is => 'Text', doc => "Output dir containing the fastq_dir" , is_optional => 1},
		aligner	=> { is => 'Text', doc => "Alignment tool to use (bowtie|maq|novoalign) [bowtie]" , is_optional => 1},
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
					
					## Print result ##
					if(-e $output_fastq)
					{
						print "$flowcell \t$lane_name \t$read_length bp $end_type\t$num_reads \t$sample \t$output_fastq\t$alignment_dir\n";

						## Run the alignment ##
						
						if($aligner eq "bowtie")
						{
							#my $reference = "/gscmnt/sata194/info/sralign/dkoboldt/human_refseq/Hs36_1c_dkoboldt.bowtie";
							my $reference = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/Hs36_1c_dkoboldt.bowtie";

							## Launch SE ##
							system("bsub -q long -R\"select[type==LINUX64 && mem>4000] rusage[mem=4000]\" -oo $alignment_outfile.log bowtie -m 1 --unfq $alignment_outfile.unmapped.fastq --maxfq $alignment_outfile.multiple.fastq $reference $output_fastq $alignment_outfile");

						
							## Launch PE ##
							if($end_type eq "PE" && $lane_pairs{"$flowcell.$lane"} eq "2")
							{
								my $file1 = $output_fastq;
								my $file2 = $output_fastq;
								$file2 =~ s/1\_sequence\.fastq/2\_sequence\.fastq/;
								my $paired_outfile = $flowcell_dir . "/" . $aligner . "_out/" . "s_" . $lane . "_paired.bowtie";
								system("bsub -q long -R\"select[type==LINUX64 && mem>4000] rusage[mem=4000]\" -oo $paired_outfile.log bowtie -m 1 -X 450 --unfq $paired_outfile.unmapped.fastq --maxfq $paired_outfile.multiple.fastq $reference -1 $file1 -2 $file2 $paired_outfile");
							}
						}
					}
					else
					{
						print "*** File Missing: $output_fastq\n";
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

