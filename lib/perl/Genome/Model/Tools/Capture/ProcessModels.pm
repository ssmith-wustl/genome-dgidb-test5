
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

		my $snp_file = $build_dir . "/snp_related_metrics/snps_all_sequences.filtered";
		my $indel_file = $build_dir . "/snp_related_metrics/indels_all_sequences.filtered";

		if(-e $bam_file && -e $snp_file && -e $indel_file)
		{
			my $varscan_snps = "";
			$varscan_snps = `cat $sample_output_dir/varScan.output.snp | wc -l` if(-e "$sample_output_dir/varScan.output.snp");
			chomp($varscan_snps) if($varscan_snps);

			my $final_snp_file = "$sample_output_dir/merged.germline.snp.ROI.tier1.out";
			my $final_snp_file2 = "$sample_output_dir/merged.germline.snp.ROI.tier2.out";
			my $final_snp_file3 = "$sample_output_dir/merged.germline.snp.ROI.tier3.out";
			my $final_snp_file4 = "$sample_output_dir/merged.germline.snp.ROI.tier4.out";

			my $final_indel_file = "$sample_output_dir/merged.germline.indel.ROI.tier1.out";
			my $final_indel_file2 = "$sample_output_dir/merged.germline.indel.ROI.tier2.out";
			my $final_indel_file3 = "$sample_output_dir/merged.germline.indel.ROI.tier3.out";
			my $final_indel_file4 = "$sample_output_dir/merged.germline.indel.ROI.tier4.out";


			my $snpexists = 0;
			my $indelexists = 0;
			if (-s $final_snp_file || -s $final_snp_file2) {
				$snpexists = 1;
			}
			elsif (-s $final_snp_file3 || -s $final_snp_file4) {
				$snpexists = 1;
				print "SHIT! ONLY TIER 3 OR 4!\n";
			}

			if (-s $final_indel_file || -s $final_indel_file2) {
				$indelexists = 1;
			}
			elsif (-s $final_indel_file3 || -s $final_indel_file4) {
				$indelexists = 1;
				print "SHIT! ONLY TIER 3 OR 4!\n";
			}

#			print "$snpexists\t$indelexists\n";

			if($self->skip_if_output_present && $snpexists && $indelexists)
			{
				## Skip because valid output ##
				print "skipped $sample_name for already having valid output\n";
			}
			else
			{
				print "$model_id\t$sample_name\t$build_status\t$build_dir\n";
				my @outfile_list = qw(annotation.germline.indel.ucsc merged.germline.indel merged.germline.indel.ROI.tier4.out merged.germline.snp.ROI samtools.output.indel.formatted varScan.output.snp annotation.germline.indel.unannot-ucsc merged.germline.indel.ROI merged.germline.indel.shared merged.germline.snp.ROI.tier1.out samtools.output.snp.adaptor varScan.output.snp.filter annotation.germline.snp.transcript merged.germline.indel.ROI.tier1.out merged.germline.indel.sniper-only merged.germline.snp.ROI.tier2.out varScan.output.indel varScan.output.snp.formatted annotation.germline.snp.ucsc merged.germline.indel.ROI.tier2.out merged.germline.indel.varscan-only merged.germline.snp.ROI.tier3.out varScan.output.indel.filter varScan.output.snp.variants annotation.germline.indel.transcript annotation.germline.snp.unannot-ucsc merged.germline.indel.ROI.tier3.out merged.germline.snp merged.germline.snp.ROI.tier4.out varScan.output.indel.formatted );
				foreach my $file (@outfile_list) {
					my $del_file = "$sample_output_dir/$file";
					unlink("$del_file");
				}

				my $cmd = "gmt germline capture-bams --build-id $build_id --germline-bam-file $bam_file --filtered-indelpe-snps $snp_file --indels-all-sequences-filtered $indel_file --data-directory $sample_output_dir --regions-file $regions_file";
				print "$cmd\n";
				my $job_name = "$sample_output_dir/$sample_name";
				my $output_name = "$sample_output_dir/$sample_name.output";
				my $error_name = "$sample_output_dir/$sample_name.err";
				unlink("$output_name");
				unlink("$error_name");
				system("bsub -q apipe -R\"select[type==LINUX64 && model != Opteron250 && mem>4000] rusage[mem=4000]\" -M 4000000 -J $job_name -o $output_name -e $error_name \"$cmd\"");
				sleep(1);
			}
		}
		else {
			print "-e bam_file && -e snp_file && -e indel_file failed";
			exit;
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

