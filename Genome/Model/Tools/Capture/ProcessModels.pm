
package Genome::Model::Tools::Capture::ProcessModels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# ProcessModels - Compare tumor versus normal models to find somatic events
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	12/09/2009 by D.K.
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
		model_list	=> { is => 'Text', doc => "Text file normal-tumor sample pairs to include, one pair per line" , is_optional => 0},
		report_only	=> { is => 'Text', doc => "Flag to skip actual execution" , is_optional => 1},
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

	my $input = new FileHandle ($model_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $model_id, my $sample_name) = split(/\t/, $line);
		$stats{'num_pairs'}++;
		
		## Establish sample output dir ##
		
		my $sample_output_dir = $output_dir . "/" . $sample_name;
		mkdir($sample_output_dir) if(!(-d $sample_output_dir));
		
		my $model_status = get_model_status($model_id);
		my @statusContents = split(/\t/, $model_status);
		my $build_id = $statusContents[1];
		my $build_status = $statusContents[2];
		my $model_dir = $statusContents[3];
		my $build_dir = $model_dir . "/build" . $build_id;
		
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
				my $cmd = "gmt germline capture-bams --build-id $build_id --germline-bam-file $bam_file --filtered-indelpe-snps $snp_file --indels-all-sequences-filtered $indel_file --data-directory $sample_output_dir";
				print "$cmd\n";
				system("bsub -q long -R\"select[type==LINUX64 && model != Opteron250 && mem>4000] rusage[mem=4000]\" -M 4000000 \"$cmd\"");
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

	}

	close($input);
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_model_status
{
	my $model_id = shift(@_);
	my $status_xml = `genome model status --genome-model-id $model_id 2>/dev/null`;
	my $build_id = my $build_status = "";
	my $build_dir = "";

	my @statusLines = split(/\n/, $status_xml);
	
	foreach my $line (@statusLines)
	{
		if($line =~ 'data-directory')
		{
			my @lineContents = split(/\"/, $line);
			my $numContents = @lineContents;
			for(my $colCounter = 0; $colCounter < $numContents; $colCounter++)
			{
				if($lineContents[$colCounter] && $lineContents[$colCounter] =~ 'data-directory')
				{
					$build_dir = $lineContents[$colCounter + 1];
				}
			}
		}
		
		if($line =~ 'builds' && !$build_status)
		{
			$build_status = "Unbuilt";
		}
		
		if($line =~ 'build id')
		{
			my @lineContents = split(/\"/, $line);
			$build_id = $lineContents[1];
		}
		
		if($line =~ 'build-status')
		{
			my @lineContents = split(/[\<\>]/, $line);
			$build_status = $lineContents[2];
		}
		

	}
	
	return("$model_id\t$build_id\t$build_status\t$build_dir");
}



1;

