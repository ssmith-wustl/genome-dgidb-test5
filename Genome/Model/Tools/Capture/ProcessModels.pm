
package Genome::Model::Tools::Capture::ProcessModels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# ProcessModels - Compare germline reference models to find germline events
#					
#	AUTHOR:		Will Schierding (wschierd@genome.wustl.edu)
#
#	CREATED:	6/19/2009 by W.S.
#	MODIFIED:	6/19/2009 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

## Declare global statistics hash ##

my %stats = ();

class Genome::Model::Tools::Capture::ProcessModels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		output_dir	=> { is => 'Text', doc => "Output directory for comparison files" , is_optional => 0},
		model_list	=> { is => 'Text', doc => "Text file id,subject_name,build_ids,build_statuses,last_succeeded_build_directory, one per line - space delim" , is_optional => 0},
		regions_file	=> { is => 'Text', doc => "Optional limit to regions file" , is_optional => 1},
		skip_if_output_present => { is => 'Text', doc => "Do not attempt to run pipeline if output present" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Perform downstream analysis on a list of genome models"                 
}

sub help_synopsis {
    return <<EOS
Perform downstream analysis on a list of genome models.  The list should be tab-delimited with model_id and sample_name as the first two columns.
EXAMPLE:	gmt capture process-models ...
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
	my $model_list = $self->model_list;
	my $output_dir = "./";
	$output_dir = $self->output_dir if($self->output_dir);
	my $regions_file = $self->regions_file if($self->regions_file);
	my $input = new FileHandle ($model_list);
	my $lineCounter = 0;
	my $i = 0;
	while (<$input>)
	{
		$i++;
		chomp;
		my $line = $_;
		$lineCounter++;
		$line =~ s/\s+/\t/g;
		my ($model_id, $sample_name, $build_id, $build_status, $build_dir) = split(/\t/, $line);
		$stats{'num_pairs'}++;
		
		## Establish sample output dir ##
		
		my $sample_output_dir = $output_dir . "/" . $sample_name;
		mkdir($sample_output_dir) if(!(-d $sample_output_dir));
		
		print "$model_id\t$sample_name\t$build_status\t$build_dir\n";

		## get the bam file ##
		
		my $bam_file = $build_dir . "/alignments/" . $build_id . "_merged_rmdup.bam";

		my $snp_file = $build_dir . "/sam_snp_related_metrics/filtered.indelpe.snps";
		my $indel_file = $build_dir . "/sam_snp_related_metrics/indels_all_sequences.filtered";

		if(-e $bam_file && -e $snp_file && -e $indel_file)
		{
			my $varscan_snps = "";
			$varscan_snps = `cat $sample_output_dir/varScan.output.snp | wc -l` if(-e "$sample_output_dir/varScan.output.snp");
			chomp($varscan_snps) if($varscan_snps);
			if($self->skip_if_output_present && $varscan_snps)
			{
				## Skip because valid output ##
			}
			else
			{
				#print "$sample_name\t$model_id\t$build_id\n";
				my $cmd = "gmt germline capture-bams --build-id $build_id --germline-bam-file $bam_file --filtered-indelpe-snps $snp_file --indels-all-sequences-filtered $indel_file --data-directory $sample_output_dir --regions-file $regions_file";
				print "$cmd\n";
				my $job_name = "$sample_output_dir/$sample_name";
				my $output_name = "$sample_output_dir/$sample_name.output";
				my $error_name = "$sample_output_dir/$sample_name.err";
				system("bsub -q apipe -R\"select[type==LINUX64 && model != Opteron250 && mem>4000] rusage[mem=4000]\" -M 4000000 -J $job_name -o $output_name -e $error_name \"$cmd\"");
				sleep(1);

				## Figure out a way to run this on bsub! ##
	#			my $cmd_obj = Genome::Model::Tools::Germline::CaptureBams->create(
	#				build_id => $build_id,
	#				germline_bam_file => $bam_file,
	#				filtered_indelpe_snps => $snp_file,
	#				indels_all_sequences_filtered => $indel_file,
	#				data_directory => $sample_output_dir,
	#			);					
	#				
	#			$cmd_obj->execute;
			}
		}
		my $count = $i%15;
		if ($count == 1) {
			sleep(1200);
		}
	}

	close($input);
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


1;

